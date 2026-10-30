//! CSS selector matching for `Element.select`, with a stop check inside the
//! matcher.
//!
//! scraper's `select` cannot be interrupted: a selector list with many
//! alternatives, or `:has(x span)`, on a document of tens of thousands of
//! nodes runs for minutes in one native call. Here the matching is driven by
//! this module instead: [`Guarded`] wraps `ElementRef` and implements the
//! `selectors` element trait by delegation, counting every tree walk the
//! matcher makes (parent, sibling and child steps, one per node looked at) and
//! the attribute text it scans (one step per KiB, more for a case-insensitive
//! substring search). Every [`CHECK_EVERY`] steps it asks the caller whether the call must stop; once it must, all
//! walks answer "nothing there" so matching unwinds quickly and the caller
//! throws the stop error.

use std::cell::Cell;
use std::fmt;

use ego_tree::{NodeId, NodeRef};
use html5ever::Namespace;
use scraper::error::SelectorErrorKind;
use scraper::selector::{CssLocalName, CssString, NonTSPseudoClass, PseudoElement, Simple};
use scraper::{ElementRef, Node};
use selectors::attr::{
    AttrSelectorOperation, AttrSelectorOperator, CaseSensitivity, NamespaceConstraint,
};
use selectors::bloom::BloomFilter;
use selectors::matching::{
    self, matches_selector_list, MatchingContext, MatchingForInvalidation, MatchingMode,
    NeedsSelectorFlags, SelectorCaches,
};
use selectors::parser::{ParseRelative, SelectorList};
use selectors::{Element, OpaqueElement};

/// Steps of matcher work between two looks at the stop check.
const CHECK_EVERY: u64 = 1 << 16;

/// A parsed selector list.
pub struct Compiled(SelectorList<Simple>);

/// Parses `css` with scraper's selector grammar (the same one its own
/// `Selector::parse` uses).
pub fn compile(css: &str) -> Result<Compiled, SelectorErrorKind> {
    let mut input = cssparser::Parser::new(css);
    SelectorList::parse(&scraper::selector::Parser, &mut input, ParseRelative::No)
        .map(Compiled)
        .map_err(SelectorErrorKind::from)
}

/// Counts matcher work and remembers why the run must stop.
struct Gate<'s> {
    steps: Cell<u64>,
    stopped: Cell<Option<u8>>,
    stop_reason: &'s dyn Fn() -> Option<u8>,
}

impl Gate<'_> {
    /// Counts `n` steps of work; false once the run must stop. The stop check
    /// runs whenever the total crosses a multiple of [`CHECK_EVERY`], also
    /// when one charge jumps over it.
    fn charge(&self, n: u64) -> bool {
        if self.stopped.get().is_some() {
            return false;
        }
        let before = self.steps.get();
        let after = before.saturating_add(n);
        self.steps.set(after);
        if after / CHECK_EVERY != before / CHECK_EVERY {
            self.stopped.set((self.stop_reason)());
        }
        self.stopped.get().is_none()
    }

    /// One node or element visited.
    fn step(&self) -> bool {
        self.charge(1)
    }

    /// Scanning `bytes` of attribute text, `times` over (the cost of one
    /// comparison relative to a plain scan).
    fn charge_bytes(&self, bytes: usize, times: usize) -> bool {
        self.charge((1 + bytes as u64 / 1024).saturating_mul(times as u64))
    }
}

/// `ElementRef` that counts its tree walks.
#[derive(Clone)]
struct Guarded<'a, 'g> {
    el: ElementRef<'a>,
    gate: &'g Gate<'g>,
}

impl fmt::Debug for Guarded<'_, '_> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Debug::fmt(&self.el, f)
    }
}

impl<'a, 'g> Guarded<'a, 'g> {
    fn wrap(&self, el: ElementRef<'a>) -> Self {
        Guarded {
            el,
            gate: self.gate,
        }
    }

    /// The walk `f` makes, or nothing once the run must stop.
    fn walk(&self, f: impl FnOnce(&ElementRef<'a>) -> Option<ElementRef<'a>>) -> Option<Self> {
        if !self.gate.step() {
            return None;
        }
        f(&self.el).map(|el| self.wrap(el))
    }

    /// The first element among `nodes`, charging one step per node looked at
    /// (a run of comments or text costs as much as a run of elements).
    fn first_element(&self, nodes: impl Iterator<Item = NodeRef<'a, Node>>) -> Option<Self> {
        for node in nodes {
            if !self.gate.step() {
                return None;
            }
            if let Some(el) = ElementRef::wrap(node) {
                return Some(self.wrap(el));
            }
        }
        None
    }
}

impl Element for Guarded<'_, '_> {
    type Impl = Simple;

    fn opaque(&self) -> OpaqueElement {
        self.el.opaque()
    }

    fn parent_element(&self) -> Option<Self> {
        self.walk(|e| e.parent_element())
    }

    fn parent_node_is_shadow_root(&self) -> bool {
        false
    }

    fn containing_shadow_host(&self) -> Option<Self> {
        None
    }

    fn is_pseudo_element(&self) -> bool {
        false
    }

    fn prev_sibling_element(&self) -> Option<Self> {
        self.first_element(self.el.prev_siblings())
    }

    fn next_sibling_element(&self) -> Option<Self> {
        self.first_element(self.el.next_siblings())
    }

    fn first_element_child(&self) -> Option<Self> {
        self.first_element(self.el.children())
    }

    fn is_html_element_in_html_document(&self) -> bool {
        self.el.is_html_element_in_html_document()
    }

    fn has_local_name(&self, name: &CssLocalName) -> bool {
        self.el.has_local_name(name)
    }

    fn has_namespace(&self, namespace: &Namespace) -> bool {
        self.el.has_namespace(namespace)
    }

    fn is_same_type(&self, other: &Self) -> bool {
        self.el.is_same_type(&other.el)
    }

    fn attr_matches(
        &self,
        ns: &NamespaceConstraint<&Namespace>,
        local_name: &CssLocalName,
        operation: &AttrSelectorOperation<&CssString>,
    ) -> bool {
        // Same test as scraper's, with the cost of each value charged first.
        let times = comparison_weight(operation);
        for (key, value) in self.el.value().attrs.iter() {
            if !self.gate.step() {
                return false;
            }
            let ns_ok = !matches!(*ns, NamespaceConstraint::Specific(url) if *url != key.ns);
            if !ns_ok || local_name.0 != key.local {
                continue;
            }
            if !self.gate.charge_bytes(value.len(), times) {
                return false;
            }
            if operation.eval_str(value) {
                return true;
            }
        }
        false
    }

    fn match_non_ts_pseudo_class(
        &self,
        _pc: &NonTSPseudoClass,
        _context: &mut MatchingContext<'_, Simple>,
    ) -> bool {
        false
    }

    fn match_pseudo_element(
        &self,
        _pe: &PseudoElement,
        _context: &mut MatchingContext<Simple>,
    ) -> bool {
        false
    }

    fn apply_selector_flags(&self, _flags: matching::ElementSelectorFlags) {}

    fn is_link(&self) -> bool {
        self.el.is_link()
    }

    fn is_html_slot_element(&self) -> bool {
        self.el.is_html_slot_element()
    }

    fn has_id(&self, id: &CssLocalName, case_sensitivity: CaseSensitivity) -> bool {
        self.el.has_id(id, case_sensitivity)
    }

    fn has_class(&self, name: &CssLocalName, case_sensitivity: CaseSensitivity) -> bool {
        // Scraper's `has_class` builds and caches a class list per element;
        // scan the attribute value instead, without allocating.
        for (key, value) in self.el.value().attrs.iter() {
            if !self.gate.step() {
                return false;
            }
            if &*key.local != "class" {
                continue;
            }
            if !self.gate.charge_bytes(value.len(), 1) {
                return false;
            }
            if value
                .split_ascii_whitespace()
                .any(|c| case_sensitivity.eq(c.as_bytes(), name.0.as_bytes()))
            {
                return true;
            }
        }
        false
    }

    fn has_custom_state(&self, _name: &CssLocalName) -> bool {
        false
    }

    fn imported_part(&self, _name: &CssLocalName) -> Option<CssLocalName> {
        None
    }

    fn is_part(&self, _name: &CssLocalName) -> bool {
        false
    }

    fn is_empty(&self) -> bool {
        for node in self.el.children() {
            if !self.gate.step() {
                return false;
            }
            if node.value().is_element() || node.value().is_text() {
                return false;
            }
        }
        true
    }

    fn is_root(&self) -> bool {
        self.el.is_root()
    }

    fn add_element_unique_hashes(&self, _filter: &mut BloomFilter) -> bool {
        false
    }
}

/// How many plain scans of the attribute value one comparison costs: a
/// case-insensitive substring search is not linear (it can compare the needle
/// at every position), so it is weighted by the needle length.
fn comparison_weight(operation: &AttrSelectorOperation<&CssString>) -> usize {
    match operation {
        AttrSelectorOperation::WithValue {
            operator,
            case_sensitivity,
            value,
        } if *operator != AttrSelectorOperator::Equal
            && *case_sensitivity == CaseSensitivity::AsciiCaseInsensitive =>
        {
            1 + value.0.len() / 16
        }
        _ => 1,
    }
}

/// The descendants of `scope` (not `scope` itself) that match `list`, in
/// document order; at most one when `first`. `Err(reason)` when
/// `stop_reason` said the run must stop (the reason it gave).
pub fn select_descendants(
    scope: ElementRef<'_>,
    list: &Compiled,
    first: bool,
    stop_reason: &dyn Fn() -> Option<u8>,
) -> Result<Vec<NodeId>, u8> {
    let gate = Gate {
        steps: Cell::new(0),
        stopped: Cell::new(None),
        stop_reason,
    };
    let scope_opaque = scope.opaque();
    let mut caches = SelectorCaches::default();
    let mut found = Vec::new();
    // `descendants()` starts with the node itself.
    for node in scope.descendants().skip(1) {
        if !gate.step() {
            break;
        }
        let Some(el) = ElementRef::wrap(node) else {
            continue;
        };
        let candidate = Guarded { el, gate: &gate };
        let mut context = MatchingContext::new(
            MatchingMode::Normal,
            None,
            &mut caches,
            matching::QuirksMode::NoQuirks,
            NeedsSelectorFlags::No,
            MatchingForInvalidation::No,
        );
        context.scope_element = Some(scope_opaque);
        // A stopped gate makes every walk fail, which can turn a `:not()`
        // true: such a result is not trusted.
        if matches_selector_list(&list.0, &candidate, &mut context) && gate.stopped.get().is_none()
        {
            found.push(el.id());
            if first {
                break;
            }
        }
    }
    match gate.stopped.get() {
        Some(reason) => Err(reason),
        None => Ok(found),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use scraper::{Html, Selector};

    const FIXTURE: &str = include_str!("../../tests/fixtures/plugin_runtime/genius_like_page.html");

    fn ours(doc: &Html, css: &str) -> Vec<NodeId> {
        let list = compile(css).unwrap_or_else(|_| panic!("selector {css:?} parses"));
        select_descendants(doc.root_element(), &list, false, &|| None).expect("not stopped")
    }

    fn scrapers(doc: &Html, css: &str) -> Vec<NodeId> {
        let sel = Selector::parse(css).expect("selector parses");
        doc.root_element().select(&sel).map(|e| e.id()).collect()
    }

    #[test]
    fn results_match_scrapers_own_select() {
        let doc = Html::parse_document(FIXTURE);
        for css in [
            "div",
            "a[href]",
            "a[href^='/songs']",
            "div[data-lyrics-container=\"true\"]",
            "ul.related li:nth-child(2)",
            "li:nth-last-child(1), h1",
            "ul > li > a",
            "main div + div",
            "li ~ li",
            "body :not(a):not(div)",
            "div:has(i)",
            "ul:has(> li a[href$='three'])",
            "div:is(.lyrics-part, .ad-slot)",
            ":root",
            "li:first-child, li:last-child",
            "p:empty, span:empty, div:empty",
            ":scope li",
        ] {
            assert_eq!(ours(&doc, css), scrapers(&doc, css), "{css}");
        }
        assert!(!ours(&doc, "div:has(i)").is_empty());
    }

    /// How many times the matcher asked whether to stop.
    fn stop_checks(doc: &Html, css: &str) -> u32 {
        let list = compile(css).unwrap_or_else(|_| panic!("selector {css:?} parses"));
        let calls = Cell::new(0u32);
        let stop = || {
            calls.set(calls.get() + 1);
            None
        };
        select_descendants(doc.root_element(), &list, false, &stop).expect("not stopped");
        calls.get()
    }

    #[test]
    fn results_match_scrapers_on_classes_attributes_and_comment_runs() {
        let page = format!(
            "<body><div class='a b  c' x='HELLOyz' data-x='en-US' id=one>t</div>\
             <div class='B a' x='yy' id=two></div><!--c--><!--c--><!--c-->\
             <div class='' x='{}z' id=three><!-- only a comment --></div><p class=a>p</p><p>q</p>\
             <!--c--><div id=four>{}</div></body>",
            "y".repeat(50_000),
            "<!--c-->".repeat(2_000),
        );
        let doc = Html::parse_document(&page);
        for css in [
            ".a",
            ".a.b",
            ".b",
            ".B",
            ".c.a.b",
            "div.a:not(.b)",
            "[x=\"helloyz\" i]",
            "[x]",
            "[x*=y i]",
            "[x*=yz]",
            "[x^=hello i]",
            "[x^=hello]",
            "[x$=Z i]",
            "[x$=z]",
            "[x=yy]",
            "[x=YY i]",
            "[class~=b]",
            "[class~=B i]",
            "[data-x|=en]",
            "[data-x|=EN i]",
            "div:empty",
            "div:not(:empty)",
            "div:first-child, p:last-child",
            "p + p, div ~ p",
            "div:nth-child(3), div:nth-last-child(2)",
            "[id=four] > :first-child",
        ] {
            assert_eq!(ours(&doc, css), scrapers(&doc, css), "{css}");
        }
        assert_eq!(ours(&doc, ".a").len(), 3);
        assert_eq!(ours(&doc, "[x*=y i]").len(), 3);
    }

    #[test]
    fn matching_work_is_charged_by_nodes_visited_not_elements_found() {
        // One <div> with 150 000 comment children; `:empty` looks at all of
        // them, 100 times over (`:not(:empty)` is false, so no alternative
        // matches early), and finds no element at all.
        let doc = Html::parse_document(&format!("<div>{}</div>", "<!--c-->".repeat(150_000)));
        let css = vec!["div:not(:empty)"; 100].join(",");
        assert!(stop_checks(&doc, &css) > 100);

        // Sibling walks count nodes too: the last <i> looks back over a long
        // run of comments (`i:first-child` needs the previous element). The
        // matcher caches the answer per element, so the walk is paid once.
        let doc = Html::parse_document(&format!(
            "<body><i></i>{}<i></i></body>",
            "<!--c-->".repeat(150_000)
        ));
        assert!(stop_checks(&doc, "i:first-child") >= 2);
    }

    #[test]
    fn class_and_attribute_scans_are_charged_by_bytes() {
        let big = "a ".repeat(512 * 1024);
        let doc = Html::parse_document(&format!(
            "<body>{}</body>",
            format!("<div class='{big}' x='{big}'></div>").repeat(8)
        ));
        // 8 elements x 150 alternatives x 1 MiB of class text.
        let classes = (0..150)
            .map(|n| format!(".c{n}"))
            .collect::<Vec<_>>()
            .join(",");
        assert!(stop_checks(&doc, &classes) >= 10);
        // Case-insensitive substring search is weighted by the needle.
        let one = format!("[x*=\"{}\" i]", "y".repeat(16));
        let many = vec![one; 40].join(",");
        assert!(stop_checks(&doc, &many) >= 8);
        // A single huge value is charged in one jump and still crosses a
        // check boundary (the check does not only fire on exact multiples).
        let doc = Html::parse_document(&format!(
            "<body><p x='{}'></p></body>",
            "a".repeat(30_000_000)
        ));
        assert!(stop_checks(&doc, "[x*=\"zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz\" i]") >= 1);
    }

    #[test]
    fn first_stops_after_one_match() {
        let doc = Html::parse_document(FIXTURE);
        let list = compile("li").ok().unwrap();
        let one = select_descendants(doc.root_element(), &list, true, &|| None).unwrap();
        assert_eq!(one.len(), 1);
    }

    #[test]
    fn a_stop_request_ends_matching_with_its_reason() {
        // Wide and deep enough for many walks per candidate.
        let src = format!("{}{}", "<span>".repeat(400), "<i>x</i>".repeat(30_000));
        let doc = Html::parse_document(&src);
        let list = compile(&vec!["x span"; 100].join(",")).ok().unwrap();
        let calls = Cell::new(0u32);
        let stop = || {
            calls.set(calls.get() + 1);
            (calls.get() >= 3).then_some(7u8)
        };
        let r = select_descendants(doc.root_element(), &list, false, &stop);
        assert_eq!(r, Err(7));
        assert_eq!(calls.get(), 3, "no further checks after the stop");
    }

    #[test]
    fn bad_selectors_are_errors() {
        for css in ["div[[", "", ":has(:has(x))", "(", "a >"] {
            assert!(compile(css).is_err(), "{css:?}");
        }
    }
}
