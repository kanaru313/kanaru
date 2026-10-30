//! `Html.parse`: HTML documents the script can query with CSS selectors.
//!
//! The documents live in a per-call arena in Rust (the `scraper` crate, run on
//! the JS thread). A script never holds a node: it holds a number that indexes
//! the arena's handle table, and every native checks that number before use.
//! The arena is dropped with the call. `js/host_prelude.js` wraps the numbers
//! into `Element` / `Elements` objects whose handles are private fields, so a
//! script cannot make up a handle either. (Private-field classes, not rquickjs
//! `classes`: no extra rquickjs feature and far less glue.)
//!
//! Limits (see `limits.rs`): input size, documents per call, nodes per
//! document, the shared Rust byte budget, and the selector size. A parse is
//! native and QuickJS' interrupt cannot stop it, so the input is fed to the
//! parser in chunks and the cancel flag, the deadline and the node count are
//! checked between chunks.

use std::cell::RefCell;
use std::collections::HashMap;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::rc::Rc;

use ego_tree::NodeId;
use rquickjs::{Ctx, Exception, Function, Object};
use scraper::error::SelectorErrorKind;
use scraper::{ElementRef, Html};

use super::host::{HostEnv, STOP_INTERNAL};
use super::host_html_select::{compile, select_descendants};
use super::host_html_serialize::{serialize_limited, SerializeStop, MAX_SERIALIZED_BYTES};
use super::host_html_sink::{build_document, BuildStop};
use super::host_html_text::text_of;
use super::limits::{
    HTML_NODE_COST_BYTES, MAX_HTML_DEPTH, MAX_HTML_DOCUMENTS, MAX_HTML_INPUT_BYTES, MAX_HTML_NODES,
    MAX_HTML_SELECTOR_BYTES,
};

/// Longest selector text echoed in an error message, in bytes. rquickjs cuts
/// a message at 255 bytes, so the echo must leave room for the description.
const SELECTOR_ECHO_BYTES: usize = 80;

/// Parsed documents and the handles given out for their elements.
#[derive(Default)]
pub struct Arena {
    docs: Vec<Html>,
    /// Handle number -> (document index, node).
    handles: Vec<(usize, NodeId)>,
    index: HashMap<(usize, NodeId), u32>,
}

impl Arena {
    /// The handle of an element, made on first use.
    fn handle_for(&mut self, doc: usize, id: NodeId) -> u32 {
        if let Some(&h) = self.index.get(&(doc, id)) {
            return h;
        }
        let h = self.handles.len() as u32;
        self.handles.push((doc, id));
        self.index.insert((doc, id), h);
        h
    }

    /// The element behind a handle number from a script; `None` for a number
    /// that was never given out (negative, fractional, out of range, NaN) or
    /// that does not name an element.
    fn element(&self, handle: f64) -> Option<(usize, ElementRef<'_>)> {
        if !(handle >= 0.0 && handle.fract() == 0.0 && handle < self.handles.len() as f64) {
            return None;
        }
        let (doc, id) = *self.handles.get(handle as usize)?;
        let node = self.docs.get(doc)?.tree.get(id)?;
        Some((doc, ElementRef::wrap(node)?))
    }
}

/// Why a native refused; becomes the exception of that name.
enum Refusal {
    Range(String),
    Syntax(String),
    Type(&'static str),
}

impl Refusal {
    fn throw(self, ctx: &Ctx<'_>) -> rquickjs::Error {
        match self {
            Refusal::Range(m) => Exception::throw_range(ctx, &m),
            Refusal::Syntax(m) => Exception::throw_syntax(ctx, &m),
            Refusal::Type(m) => Exception::throw_type(ctx, m),
        }
    }
}

fn bad_handle() -> Refusal {
    Refusal::Type("Html: not an element of this call")
}

/// The selector text for an error message: at most [`SELECTOR_ECHO_BYTES`]
/// bytes, cut on a character boundary.
fn echo(css: &str) -> String {
    let mut end = css.len().min(SELECTOR_ECHO_BYTES);
    while !css.is_char_boundary(end) {
        end -= 1;
    }
    let more = if end < css.len() { "..." } else { "" };
    format!("{}{more}", &css[..end])
}

/// The value of attribute `name`, or `""`: an exact match first (SVG keeps
/// `viewBox`), then the lower-case name (HTML names are stored lower case). Walks the attribute list instead of scraper's `attr`, whose binary
/// search misses names the parser adjusted.
fn attribute(el: &ElementRef<'_>, name: &str) -> String {
    let attrs = el.value().attrs();
    let lower = name.to_ascii_lowercase();
    let found = attrs
        .clone()
        .find(|(n, _)| *n == name)
        .or_else(|| attrs.clone().find(|(n, _)| *n == lower));
    found.map(|(_, v)| v.to_owned()).unwrap_or_default()
}

/// Runs a native so that a panic cannot cross into QuickJS, where a script's
/// `try`/`catch` would swallow it. A panic stops the run with the internal
/// reason (status `internal`, even if the script goes on) and throws a fixed
/// message.
fn guarded<'js, T>(
    ctx: &Ctx<'js>,
    env: &HostEnv,
    f: impl FnOnce() -> rquickjs::Result<T>,
) -> rquickjs::Result<T> {
    match catch_unwind(AssertUnwindSafe(f)) {
        Ok(result) => result,
        Err(_) => {
            env.mark_stopped(STOP_INTERNAL);
            Err(Exception::throw_message(ctx, "Html: internal error"))
        }
    }
}

/// Parses `src` into the arena and returns the handle of its `<html>` element.
fn parse<'js>(
    ctx: &Ctx<'js>,
    env: &HostEnv,
    arena: &RefCell<Arena>,
    src: &str,
) -> rquickjs::Result<u32> {
    if src.len() > MAX_HTML_INPUT_BYTES {
        return Err(Refusal::Range(format!(
            "Html.parse: the text is larger than the limit of {MAX_HTML_INPUT_BYTES} bytes"
        ))
        .throw(ctx));
    }
    let documents_full = arena.borrow().docs.len() >= MAX_HTML_DOCUMENTS;
    if documents_full {
        return Err(Refusal::Range(format!(
            "Html.parse: at most {MAX_HTML_DOCUMENTS} documents per call"
        ))
        .throw(ctx));
    }
    env.check_alive(ctx)?;
    let mut stopped = None;
    let built = build_document(src, MAX_HTML_NODES, MAX_HTML_DEPTH, &env.budget, || {
        stopped = env.stop_reason();
        stopped.is_none()
    });
    let built = match built {
        Ok(built) => built,
        Err(BuildStop::NodeCap) => {
            // Same outcome as a byte budget overrun: the call ends `memory`.
            env.budget.mark_hit();
            return Err(Refusal::Range(format!(
                "Html.parse: the document has more than {MAX_HTML_NODES} nodes"
            ))
            .throw(ctx));
        }
        Err(BuildStop::OverBudget) => {
            // The budget marked itself when it refused.
            return Err(Refusal::Range(
                "Html.parse: the documents kept in memory exceed the limit".to_owned(),
            )
            .throw(ctx));
        }
        Err(BuildStop::DepthCap) => {
            return Err(Refusal::Range(format!(
                "Html.parse: the elements are nested more than {} levels deep",
                MAX_HTML_DEPTH.unwrap_or(0)
            ))
            .throw(ctx))
        }
        Err(BuildStop::Aborted) => {
            return Err(env.stop_error(ctx, stopped.unwrap_or(super::host::STOP_CANCELLED)))
        }
    };
    env.check_alive(ctx)?;
    let html = built.html;
    let cost = html
        .tree
        .nodes()
        .len()
        .saturating_mul(HTML_NODE_COST_BYTES)
        .saturating_add(src.len());
    if !env.budget.try_charge(cost) {
        return Err(Refusal::Range(
            "Html.parse: the documents kept in memory exceed the limit".to_owned(),
        )
        .throw(ctx));
    }
    let root = html
        .tree
        .root()
        .children()
        .find(|c| c.value().is_element())
        .map(|c| c.id());
    let handle = root.map(|root| {
        let mut arena = arena.borrow_mut();
        arena.docs.push(html);
        let doc = arena.docs.len() - 1;
        arena.handle_for(doc, root)
    });
    match handle {
        Some(handle) => Ok(handle),
        None => {
            env.budget.release(cost);
            Err(Refusal::Type("Html.parse: the document has no root").throw(ctx))
        }
    }
}

/// The message of a selector the parser refused: the capped selector text and
/// the reason. Reasons the parser has no useful text for get a fixed one.
fn syntax_message(css: &str, e: &SelectorErrorKind) -> String {
    let reason = match e {
        SelectorErrorKind::UnexpectedSelectorParseError(_) => "not supported".to_owned(),
        other => other.to_string(),
    };
    format!("invalid CSS selector '{}': {reason}", echo(css))
}

/// Handles of the descendants of `handle` that match `css` (at most one when
/// `first`).
fn select<'js>(
    ctx: &Ctx<'js>,
    env: &HostEnv,
    arena: &RefCell<Arena>,
    handle: f64,
    css: &str,
    first: bool,
) -> rquickjs::Result<Vec<u32>> {
    #[cfg(test)]
    if css == "__panic__" {
        panic!("test panic in select");
    }
    if css.len() > MAX_HTML_SELECTOR_BYTES {
        return Err(Refusal::Syntax(format!(
            "invalid CSS selector (longer than {MAX_HTML_SELECTOR_BYTES} bytes)"
        ))
        .throw(ctx));
    }
    let list = match compile(css) {
        Ok(list) => list,
        Err(e) => return Err(Refusal::Syntax(syntax_message(css, &e)).throw(ctx)),
    };
    env.check_alive(ctx)?;
    // The arena is borrowed only inside this block; nothing is thrown in it.
    let found = {
        let arena = arena.borrow();
        arena.element(handle).map(|(doc, scope)| {
            (
                doc,
                select_descendants(scope, &list, first, &|| env.stop_reason()),
            )
        })
    };
    let Some((doc, result)) = found else {
        return Err(bad_handle().throw(ctx));
    };
    let ids = match result {
        Ok(ids) => ids,
        Err(why) => return Err(env.stop_error(ctx, why)),
    };
    env.check_alive(ctx)?;
    let mut arena = arena.borrow_mut();
    Ok(ids
        .into_iter()
        .map(|id| arena.handle_for(doc, id))
        .collect())
}

/// The HTML of the element behind `handle`, refused past the output cap or
/// the byte budget (both end the call `memory`).
fn html_of<'js>(
    ctx: &Ctx<'js>,
    env: &HostEnv,
    arena: &RefCell<Arena>,
    handle: f64,
    outer: bool,
) -> rquickjs::Result<String> {
    let result = with_element(ctx, env, arena, handle, |el| {
        serialize_limited(&el, outer, &env.budget, MAX_SERIALIZED_BYTES)
    })?;
    result.map_err(|why| {
        // The budget already marked itself when it was the one refusing.
        if why == SerializeStop::TooLarge {
            env.budget.mark_hit();
        }
        Refusal::Range(format!(
            "Element.html: the HTML is larger than {} MiB or the memory limit",
            MAX_SERIALIZED_BYTES >> 20
        ))
        .throw(ctx)
    })
}

/// Runs `f` on the element behind `handle`, or throws for a bad handle.
fn with_element<'js, T>(
    ctx: &Ctx<'js>,
    env: &HostEnv,
    arena: &RefCell<Arena>,
    handle: f64,
    f: impl FnOnce(ElementRef<'_>) -> T,
) -> rquickjs::Result<T> {
    env.check_alive(ctx)?;
    // The borrow ends before anything is thrown.
    let out = {
        let arena = arena.borrow();
        arena.element(handle).map(|(_, el)| f(el))
    };
    out.ok_or_else(|| bad_handle().throw(ctx))
}

/// Native `htmlParse`, `htmlSelect`, `htmlText`, `htmlHtml`, `htmlAttr`,
/// `htmlTag`. The prelude turns them into `Html`, `Element` and `Elements`.
pub fn register<'js>(
    ctx: &Ctx<'js>,
    natives: &Object<'js>,
    env: &Rc<HostEnv>,
) -> rquickjs::Result<()> {
    let arena = Rc::new(RefCell::new(Arena::default()));
    let (e, a) = (env.clone(), arena.clone());
    natives.set(
        "htmlParse",
        Function::new(ctx.clone(), move |ctx: Ctx<'js>, src: String| {
            guarded(&ctx, &e, || parse(&ctx, &e, &a, &src))
        })?,
    )?;
    let (e, a) = (env.clone(), arena.clone());
    natives.set(
        "htmlSelect",
        Function::new(
            ctx.clone(),
            move |ctx: Ctx<'js>, handle: f64, css: String, first: bool| {
                guarded(&ctx, &e, || select(&ctx, &e, &a, handle, &css, first))
            },
        )?,
    )?;
    let (e, a) = (env.clone(), arena.clone());
    natives.set(
        "htmlText",
        Function::new(ctx.clone(), move |ctx: Ctx<'js>, handle: f64| {
            guarded(&ctx, &e, || with_element(&ctx, &e, &a, handle, text_of))
        })?,
    )?;
    let (e, a) = (env.clone(), arena.clone());
    natives.set(
        "htmlHtml",
        Function::new(
            ctx.clone(),
            move |ctx: Ctx<'js>, handle: f64, outer: bool| {
                guarded(&ctx, &e, || html_of(&ctx, &e, &a, handle, outer))
            },
        )?,
    )?;
    let (e, a) = (env.clone(), arena.clone());
    natives.set(
        "htmlAttr",
        Function::new(
            ctx.clone(),
            move |ctx: Ctx<'js>, handle: f64, name: String| {
                guarded(&ctx, &e, || {
                    with_element(&ctx, &e, &a, handle, |el| attribute(&el, &name))
                })
            },
        )?,
    )?;
    let (e, a) = (env.clone(), arena);
    natives.set(
        "htmlTag",
        Function::new(ctx.clone(), move |ctx: Ctx<'js>, handle: f64| {
            guarded(&ctx, &e, || {
                with_element(&ctx, &e, &a, handle, |el| el.value().name().to_owned())
            })
        })?,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn arena_with(html: &str) -> (Arena, u32) {
        let mut arena = Arena::default();
        let doc = Html::parse_document(html);
        let root = doc.root_element().id();
        arena.docs.push(doc);
        let h = arena.handle_for(0, root);
        (arena, h)
    }

    #[test]
    fn handles_are_stable_and_checked() {
        let (mut arena, root) = arena_with("<body><p>x</p></body>");
        assert_eq!(arena.handle_for(0, arena.handles[root as usize].1), root);
        assert!(arena.element(f64::from(root)).is_some());
        for forged in [
            -1.0,
            0.5,
            1.0,
            1e9,
            f64::NAN,
            f64::INFINITY,
            f64::NEG_INFINITY,
        ] {
            assert!(arena.element(forged).is_none(), "{forged}");
        }
        // A handle whose document does not exist.
        arena.handles.push((7, arena.handles[0].1));
        assert!(arena.element(1.0).is_none(), "document index out of range");
    }

    #[test]
    fn handle_of_a_text_node_is_refused() {
        let (mut arena, _) = arena_with("<body>plain</body>");
        let text = arena.docs[0]
            .tree
            .nodes()
            .find(|n| n.value().is_text())
            .map(|n| n.id())
            .expect("a text node");
        let h = arena.handle_for(0, text);
        assert!(arena.element(f64::from(h)).is_none());
    }
}
