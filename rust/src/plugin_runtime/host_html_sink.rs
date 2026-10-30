//! Builds the `scraper` tree of `Html.parse` with hard bounds.
//!
//! html5ever can create far more nodes than the input has tags: reconstructing
//! the list of active formatting elements clones every open `<b id=k>` again
//! at each `<p>`, so a few KiB of input make millions of nodes. A count taken
//! between chunks of input is therefore no bound. [`CountingSink`] wraps the
//! tree sink instead: past the node cap every create and every tree change is
//! a no-op (creates return one sentinel element), the cap flag is set, and the
//! caller stops at the end of the chunk. The wrapper also tracks how deep the
//! elements nest, for the optional depth limit.

use std::cell::{Cell, Ref, RefCell};
use std::collections::HashMap;
use std::rc::Rc;

use ego_tree::{iter::Edge, NodeId};
use html5ever::driver::{self, ParseOpts};
use html5ever::tendril::{StrTendril, TendrilSink};
use html5ever::tree_builder::{ElementFlags, NodeOrText, QuirksMode, TreeSink};
use html5ever::{local_name, ns, Attribute, QualName};
use scraper::{Html, HtmlTreeSink, Node};

use super::host_budget::ByteBudget;
use super::host_callback::quietly_catching;
use std::borrow::Cow;

/// Input handed to the parser per step. Small on purpose: html5ever takes
/// time quadratic in the nesting depth for some tags (`<div>` repeated tens of
/// thousands of times), so the cancel flag and the deadline are looked at after
/// every 1 KiB, which bounds how long a stop request waits.
const PARSE_CHUNK_BYTES: usize = 1024;
/// Levels past the depth limit the chunked parse tolerates before it stops
/// early (see `build_document`).
const EARLY_DEPTH_MARGIN: u32 = 64;
/// Bytes one attribute takes in an element besides its text: the name atoms
/// and the value handle.
const ATTRIBUTE_SLOT_BYTES: usize = std::mem::size_of::<(html5ever::QualName, StrTendril)>();

/// Why a build stopped before it had a document.
#[derive(Debug, PartialEq, Eq)]
pub enum BuildStop {
    /// More nodes than the cap.
    NodeCap,
    /// The attribute text of the elements (clones included) would pass the
    /// byte budget. The budget is marked as hit.
    OverBudget,
    /// Elements nested deeper than the depth limit.
    DepthCap,
    /// The caller's `keep_going` said stop (cancel, deadline).
    Aborted,
}

/// A finished document.
pub struct Built {
    pub html: Html,
    /// Deepest element nesting, counted from the document node: the `<html>`
    /// element is depth 1, its `<body>` 2.
    #[allow(dead_code)] // measured for the depth limit and read by tests
    pub max_depth: u32,
}

/// The tree sink html5ever drives: [`HtmlTreeSink`] plus the bounds.
struct CountingSink<'b> {
    inner: HtmlTreeSink,
    /// Every created element's attribute text is charged here, clones that
    /// html5ever makes while repairing markup included: they share one buffer
    /// in memory, but anything that reads them (the matcher, the serializer)
    /// sees each copy in full.
    budget: &'b ByteBudget,
    charged: Rc<Cell<usize>>,
    /// `over` was set by the budget, not by the node count.
    refused: Cell<bool>,
    max_nodes: usize,
    /// Set for good the first time the tree is found past `max_nodes`.
    over: Cell<bool>,
    /// The element handed out for every create after `over`.
    sentinel: Cell<Option<NodeId>>,
    /// Depth of each element when it was attached. Reparenting can leave a
    /// descendant's value stale, so this only drives the early depth limit;
    /// the reported depth is measured on the finished tree.
    depth: RefCell<HashMap<NodeId, u32>>,
    max_depth: Cell<u32>,
}

impl<'b> CountingSink<'b> {
    fn new(max_nodes: usize, budget: &'b ByteBudget, charged: Rc<Cell<usize>>) -> Self {
        Self {
            inner: HtmlTreeSink::new(Html::new_document()),
            budget,
            charged,
            refused: Cell::new(false),
            max_nodes,
            over: Cell::new(false),
            sentinel: Cell::new(None),
            depth: RefCell::new(HashMap::new()),
            max_depth: Cell::new(0),
        }
    }

    /// True once the tree has more nodes than the cap. Every operation that
    /// can add a node asks first, and each adds at most two.
    fn full(&self) -> bool {
        if self.over.get() {
            return true;
        }
        if self.inner.0.borrow().tree.nodes().len() > self.max_nodes {
            self.over.set(true);
        }
        self.over.get()
    }

    /// Charges the memory a set of attributes takes in the tree (name and value
    /// text, and the attribute slot in the element). False, with the sink
    /// stopped, when the budget refuses.
    fn charge_attrs(&self, attrs: &[Attribute]) -> bool {
        if attrs.is_empty() {
            return true;
        }
        let bytes: usize = attrs
            .iter()
            .map(|a| a.name.local.len() + a.value.len() + ATTRIBUTE_SLOT_BYTES)
            .sum();
        if !self.budget.try_charge(bytes) {
            self.refused.set(true);
            self.over.set(true);
            return false;
        }
        self.charged.set(self.charged.get() + bytes);
        true
    }

    /// Why `over` is set.
    fn stop(&self) -> BuildStop {
        if self.refused.get() {
            BuildStop::OverBudget
        } else {
            BuildStop::NodeCap
        }
    }

    /// The one element handed out after the cap.
    fn sentinel(&self) -> NodeId {
        if let Some(id) = self.sentinel.get() {
            return id;
        }
        let name = QualName::new(None, ns!(html), local_name!("span"));
        let id = self
            .inner
            .create_element(name, Vec::new(), ElementFlags::default());
        self.sentinel.set(Some(id));
        id
    }

    fn depth_of(&self, id: NodeId) -> u32 {
        self.depth.borrow().get(&id).copied().unwrap_or(0)
    }

    /// Notes that `child` was attached at `depth` (elements only).
    fn note_attached(&self, child: &NodeOrText<NodeId>, depth: u32) {
        let NodeOrText::AppendNode(id) = child else {
            return;
        };
        let is_element = self
            .inner
            .0
            .borrow()
            .tree
            .get(*id)
            .is_some_and(|n| n.value().is_element());
        if is_element {
            self.depth.borrow_mut().insert(*id, depth);
            self.max_depth.set(self.max_depth.get().max(depth));
        }
    }
}

impl TreeSink for CountingSink<'_> {
    type Handle = NodeId;
    type Output = Html;
    type ElemName<'a>
        = Ref<'a, QualName>
    where
        Self: 'a;

    fn finish(self) -> Html {
        self.inner.finish()
    }

    fn parse_error(&self, msg: Cow<'static, str>) {
        self.inner.parse_error(msg);
    }

    fn get_document(&self) -> NodeId {
        self.inner.get_document()
    }

    fn elem_name<'a>(&'a self, target: &'a NodeId) -> Ref<'a, QualName> {
        self.inner.elem_name(target)
    }

    fn create_element(&self, name: QualName, attrs: Vec<Attribute>, flags: ElementFlags) -> NodeId {
        if self.full() {
            return self.sentinel();
        }
        if !self.charge_attrs(&attrs) {
            return self.sentinel();
        }
        self.inner.create_element(name, attrs, flags)
    }

    fn create_comment(&self, text: StrTendril) -> NodeId {
        if self.full() {
            return self.sentinel();
        }
        self.inner.create_comment(text)
    }

    fn create_pi(&self, target: StrTendril, data: StrTendril) -> NodeId {
        if self.full() {
            return self.sentinel();
        }
        self.inner.create_pi(target, data)
    }

    fn append(&self, parent: &NodeId, child: NodeOrText<NodeId>) {
        if self.full() {
            return;
        }
        self.note_attached(&child, self.depth_of(*parent) + 1);
        self.inner.append(parent, child);
    }

    fn append_based_on_parent_node(
        &self,
        element: &NodeId,
        prev_element: &NodeId,
        child: NodeOrText<NodeId>,
    ) {
        let has_parent = self
            .inner
            .0
            .borrow()
            .tree
            .get(*element)
            .is_some_and(|n| n.parent().is_some());
        if has_parent {
            self.append_before_sibling(element, child);
        } else {
            self.append(prev_element, child);
        }
    }

    fn append_doctype_to_document(
        &self,
        name: StrTendril,
        public_id: StrTendril,
        system_id: StrTendril,
    ) {
        if self.full() {
            return;
        }
        self.inner
            .append_doctype_to_document(name, public_id, system_id);
    }

    fn get_template_contents(&self, target: &NodeId) -> NodeId {
        self.inner.get_template_contents(target)
    }

    fn same_node(&self, x: &NodeId, y: &NodeId) -> bool {
        x == y
    }

    fn set_quirks_mode(&self, mode: QuirksMode) {
        self.inner.set_quirks_mode(mode);
    }

    fn append_before_sibling(&self, sibling: &NodeId, new_node: NodeOrText<NodeId>) {
        if self.full() {
            return;
        }
        self.note_attached(&new_node, self.depth_of(*sibling));
        self.inner.append_before_sibling(sibling, new_node);
    }

    fn add_attrs_if_missing(&self, target: &NodeId, attrs: Vec<Attribute>) {
        if self.full() {
            return;
        }
        // Scraper does a binary search and a `Vec::insert` per attribute:
        // quadratic for a tag with a hundred thousand attributes, and not
        // interruptible. Filter once, charge, add everything, sort once.
        let mut tree = self.inner.0.borrow_mut();
        let Some(mut node) = tree.tree.get_mut(*target) else {
            return;
        };
        let Node::Element(el) = node.value() else {
            return;
        };
        let missing: Vec<Attribute> = attrs
            .into_iter()
            .filter(|a| el.attrs.binary_search_by(|(n, _)| n.cmp(&a.name)).is_err())
            .collect();
        if missing.is_empty() || !self.charge_attrs(&missing) {
            return;
        }
        el.attrs
            .extend(missing.into_iter().map(|a| (a.name, a.value)));
        el.attrs.sort_by(|a, b| a.0.cmp(&b.0));
        el.attrs.dedup_by(|a, b| a.0 == b.0);
    }

    fn remove_from_parent(&self, target: &NodeId) {
        if self.full() {
            return;
        }
        self.inner.remove_from_parent(target);
    }

    fn reparent_children(&self, node: &NodeId, new_parent: &NodeId) {
        if self.full() {
            return;
        }
        self.inner.reparent_children(node, new_parent);
    }
}

/// Largest prefix of `text` that is at most `max` bytes and ends on a char
/// boundary (at least one char, so the loop over chunks always advances).
pub fn chunk_end(text: &str, max: usize) -> usize {
    if text.len() <= max {
        return text.len();
    }
    let mut end = max;
    while !text.is_char_boundary(end) {
        end -= 1;
    }
    if end == 0 {
        end = text.chars().next().map_or(0, char::len_utf8);
    }
    end
}

/// Deepest element nesting of a finished tree (iterative: no stack growth).
fn measured_depth(html: &Html) -> u32 {
    let (mut depth, mut deepest) = (0u32, 0u32);
    for edge in html.tree.root().traverse() {
        match edge {
            Edge::Open(n) if n.value().is_element() => {
                depth += 1;
                deepest = deepest.max(depth);
            }
            Edge::Close(n) if n.value().is_element() => depth -= 1,
            _ => {}
        }
    }
    deepest
}

/// Parses `src` as a document, one chunk at a time. Stops with
/// [`BuildStop::NodeCap`] when the tree would pass `max_nodes`,
/// [`BuildStop::OverBudget`] when the attribute text would pass `budget`
/// (what a finished document charged stays charged; a refused one gives it
/// back), [`BuildStop::DepthCap`] when elements nest deeper than `max_depth`
/// (when there is a limit), and [`BuildStop::Aborted`] when `keep_going`
/// (asked after every chunk) returns false.
pub fn build_document(
    src: &str,
    max_nodes: usize,
    max_depth: Option<u32>,
    budget: &ByteBudget,
    keep_going: impl FnMut() -> bool,
) -> Result<Built, BuildStop> {
    let charged = Rc::new(Cell::new(0));
    let result = parse_chunks(src, max_nodes, max_depth, budget, &charged, keep_going);
    if result.is_err() {
        budget.release(charged.get());
    }
    result
}

/// What html5ever panicked with, when that is not the cap: say so, since the
/// quiet hook hid it, and pass the payload on.
fn resume_real_panic(payload: Box<dyn std::any::Any + Send>) -> ! {
    let text = payload
        .downcast_ref::<&str>()
        .map(|s| (*s).to_owned())
        .or_else(|| payload.downcast_ref::<String>().cloned())
        .unwrap_or_default();
    eprintln!("html5ever panicked below the node cap: {text}");
    std::panic::resume_unwind(payload)
}

fn parse_chunks(
    src: &str,
    max_nodes: usize,
    max_depth: Option<u32>,
    budget: &ByteBudget,
    charged: &Rc<Cell<usize>>,
    mut keep_going: impl FnMut() -> bool,
) -> Result<Built, BuildStop> {
    let sink = CountingSink::new(max_nodes, budget, charged.clone());
    let mut parser = driver::parse_document(sink, ParseOpts::default());
    let mut rest = src;
    while !rest.is_empty() {
        let end = chunk_end(rest, PARSE_CHUNK_BYTES);
        let piece = StrTendril::from_slice(&rest[..end]);
        // Past the cap every element is the one sentinel, which can confuse
        // html5ever into a panic ("no current element"). That panic is the
        // cap, not a bug: it is caught and silenced.
        if let Err(payload) = quietly_catching(|| parser.process(piece)) {
            let sink = &parser.tokenizer.sink.sink;
            if sink.over.get() {
                return Err(sink.stop());
            }
            resume_real_panic(payload);
        }
        rest = &rest[end..];
        // Dropping the parser frees the partial tree at once.
        let sink = &parser.tokenizer.sink.sink;
        if sink.over.get() {
            return Err(sink.stop());
        }
        // Stale depths after a reparent can over-estimate a little, so the
        // early stop has a margin; the exact check on the finished tree
        // below enforces the limit itself.
        if max_depth.is_some_and(|limit| sink.max_depth.get() > limit + EARLY_DEPTH_MARGIN) {
            return Err(BuildStop::DepthCap);
        }
        if !keep_going() {
            return Err(BuildStop::Aborted);
        }
    }
    let stop = {
        let sink = &parser.tokenizer.sink.sink;
        sink.over.get().then(|| sink.stop())
    };
    let html = match quietly_catching(|| parser.finish()) {
        Ok(html) => html,
        Err(payload) => match stop {
            Some(stop) => return Err(stop),
            None => resume_real_panic(payload),
        },
    };
    if let Some(stop) = stop {
        return Err(stop);
    }
    if html.tree.nodes().len() > max_nodes {
        return Err(BuildStop::NodeCap);
    }
    let max_depth_seen = measured_depth(&html);
    if max_depth.is_some_and(|limit| max_depth_seen > limit) {
        return Err(BuildStop::DepthCap);
    }
    Ok(Built {
        html,
        max_depth: max_depth_seen,
    })
}

#[cfg(test)]
#[path = "host_html_sink_tests.rs"]
mod tests;
