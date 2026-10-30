//! Unit tests of the bounded tree builder.

use super::*;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

fn budget(limit: usize) -> (ByteBudget, Arc<AtomicBool>) {
    let hit = Arc::new(AtomicBool::new(false));
    (ByteBudget::new(limit, hit.clone()), hit)
}

/// `build_document` with a budget nothing here can reach.
fn build_document(
    src: &str,
    max_nodes: usize,
    max_depth: Option<u32>,
    keep_going: impl FnMut() -> bool,
) -> Result<Built, BuildStop> {
    let (b, _) = budget(usize::MAX);
    super::build_document(src, max_nodes, max_depth, &b, keep_going)
}

fn build(src: &str) -> Result<Built, BuildStop> {
    build_document(src, 200_000, None, || true)
}

#[test]
fn many_distinct_formatting_elements_cannot_pass_the_node_cap() {
    // 10 000 open `<b id=k>`, then `<p>x` again and again: html5ever
    // clones all 10 000 at each `<p>`.
    let mut src = String::from("<body><p>");
    for i in 0..10_000 {
        src.push_str(&format!("<b id={i}>"));
    }
    src.push_str("</p>");
    while src.len() < 200 * 1024 {
        src.push_str("<p>x");
    }
    let started = std::time::Instant::now();
    assert_eq!(build(&src).err(), Some(BuildStop::NodeCap));
    assert!(started.elapsed().as_secs() < 20, "{:?}", started.elapsed());
}

#[test]
fn a_single_chunk_cannot_overshoot_the_cap_by_much() {
    // The same input, a small cap: the tree the sink built stays near it.
    let mut src = String::from("<body><p>");
    for i in 0..1_000 {
        src.push_str(&format!("<b id={i}>"));
    }
    src.push_str("</p>");
    src.push_str(&"<p>x".repeat(200));
    let (b, _) = budget(usize::MAX);
    let sink = CountingSink::new(5_000, &b, Rc::new(Cell::new(0)));
    let mut parser = driver::parse_document(sink, ParseOpts::default());
    parser.process(StrTendril::from_slice(&src));
    let nodes = parser
        .tokenizer
        .sink
        .sink
        .inner
        .0
        .borrow()
        .tree
        .nodes()
        .len();
    assert!(parser.tokenizer.sink.sink.over.get());
    assert!(nodes < 5_100, "{nodes} nodes for a cap of 5000");
}

#[test]
fn max_depth_is_measured_from_the_document_node() {
    let built = build("<div><div><div>x</div></div></div>").ok().unwrap();
    // html, body and three divs.
    assert_eq!(built.max_depth, 5);
    let built = build("").ok().unwrap();
    assert_eq!(built.max_depth, 2, "html with head and body side by side");
    let deep = format!("{}x{}", "<span>".repeat(300), "</span>".repeat(300));
    assert_eq!(build(&deep).ok().unwrap().max_depth, 302);
}

#[test]
fn the_depth_limit_hook_is_off_by_default_and_works_when_set() {
    let deep = format!("{}x", "<span>".repeat(100));
    assert!(build_document(&deep, 200_000, None, || true).is_ok());
    assert_eq!(
        build_document(&deep, 200_000, Some(50), || true).err(),
        Some(BuildStop::DepthCap)
    );
    assert!(build_document(&deep, 200_000, Some(102), || true).is_ok());
}

#[test]
fn keep_going_false_aborts_between_chunks() {
    let src = "<p>x</p>".repeat(5_000);
    let mut calls = 0;
    let r = build_document(&src, 200_000, None, || {
        calls += 1;
        calls < 3
    });
    assert_eq!(r.err(), Some(BuildStop::Aborted));
    assert_eq!(calls, 3);
}

#[test]
fn the_wrapper_builds_the_same_tree_as_scraper() {
    let page = include_str!("../../tests/fixtures/plugin_runtime/genius_like_page.html");
    let built = build(page).ok().unwrap();
    assert_eq!(built.html.html(), Html::parse_document(page).html());
    eprintln!("genius-like fixture max depth: {}", built.max_depth);
}

#[test]
fn chunks_split_on_char_boundaries_and_advance() {
    let s = "aé€😀".repeat(5);
    let mut rest = s.as_str();
    let mut parts = 0;
    while !rest.is_empty() {
        let end = chunk_end(rest, 3);
        assert!(end > 0 && rest.is_char_boundary(end));
        rest = &rest[end..];
        parts += 1;
    }
    assert!(parts >= 5);
    assert_eq!(chunk_end("😀", 1), 4, "one char is always taken");
}

#[test]
fn deep_junk_stops_early_and_a_depth_limit_still_applies_to_the_final_tree() {
    let junk = "<span>".repeat(100_000);
    let mut checks = 0;
    let r = build_document(&junk, 200_000, Some(512), || {
        checks += 1;
        true
    });
    assert_eq!(r.err(), Some(BuildStop::DepthCap));
    // 512 + margin levels are 3.5 KiB of input: a handful of chunks.
    assert!(checks < 10, "{checks} chunks before the early stop");

    // Exactly at the limit is accepted, one more level is refused.
    let at = "<span>".repeat(510);
    assert!(build_document(&at, 200_000, Some(512), || true).is_ok());
    let over = "<span>".repeat(511);
    assert_eq!(
        build_document(&over, 200_000, Some(512), || true).err(),
        Some(BuildStop::DepthCap)
    );
}

#[test]
fn tag_soup_that_made_html5ever_panic_past_the_cap_is_a_node_cap() {
    let soup = include_str!("../../tests/fixtures/plugin_runtime/tag_soup_sentinel_panic.html");
    for cap in 1..400 {
        // Whatever the cap, the call ends with a result and never panics out.
        let _ = build_document(soup, cap, None, || true);
    }
}

/// Small deterministic generator (xorshift) for the soup below.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        self.0
    }

    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
}

#[test]
fn random_tag_soup_with_a_small_cap_never_panics_out() {
    const TAGS: [&str; 34] = [
        "b", "i", "a", "p", "div", "span", "table", "tr", "td", "th", "tbody", "caption", "li",
        "ul", "ol", "dl", "dt", "dd", "h1", "form", "select", "option", "optgroup", "button",
        "font", "nobr", "svg", "math", "template", "frameset", "noscript", "pre", "object", "em",
    ];
    let mut rng = Rng(0x9E37_79B9_7F4A_7C15);
    for round in 0..3_000 {
        let mut src = String::new();
        for _ in 0..rng.below(60) + 1 {
            let tag = TAGS[rng.below(TAGS.len())];
            match rng.below(6) {
                0 | 1 => src.push_str(&format!("<{tag}>")),
                2 => src.push_str(&format!("<{tag} id={round}>")),
                3 => src.push_str(&format!("</{tag}>")),
                4 => src.push_str("text "),
                _ => src.push_str("<!-- c -->"),
            }
        }
        let cap = 5 + rng.below(80);
        let _ = build_document(&src, cap, None, || true);
    }
}

#[test]
fn attribute_text_of_clones_is_charged_and_ends_the_parse_fast() {
    // html5ever clones the `<b title=...>` at every `<p>`: 27 000 clones of a
    // 3 MB value would be 81 GB for anything that reads them.
    let src = format!(
        "<body><p><b title={}></p>{}",
        "a".repeat(3_000_000),
        "<p>x".repeat(27_000)
    );
    let (b, hit) = budget(16 * 1024 * 1024);
    let started = std::time::Instant::now();
    let r = super::build_document(&src, 200_000, None, &b, || true);
    assert_eq!(r.err(), Some(BuildStop::OverBudget));
    assert!(hit.load(Ordering::SeqCst), "the budget is marked as hit");
    assert!(started.elapsed().as_secs() < 20, "{:?}", started.elapsed());
    // The failed parse gave its charge back.
    assert!(b.try_charge(16 * 1024 * 1024));
}

#[test]
fn a_finished_document_keeps_its_attribute_text_charged() {
    let page = include_str!("../../tests/fixtures/plugin_runtime/genius_like_page.html");
    let (b, hit) = budget(1024 * 1024);
    assert!(super::build_document(page, 200_000, None, &b, || true).is_ok());
    assert!(
        !hit.load(Ordering::SeqCst),
        "a realistic page is far below the budget"
    );
    assert!(!b.try_charge(1024 * 1024), "something stays charged");
}

#[test]
fn attributes_of_a_repeated_html_tag_are_merged_without_overwriting() {
    let built = build_document("<html a=1><body><html b=2 a=9 c=3>x", 1000, None, || true)
        .ok()
        .unwrap();
    let root = built.html.root_element();
    let attrs: Vec<(&str, &str)> = root.value().attrs().collect();
    assert_eq!(attrs, vec![("a", "1"), ("b", "2"), ("c", "3")]);
}

#[test]
fn a_tag_with_a_hundred_thousand_descending_attributes_is_merged_fast() {
    let mut names: Vec<String> = (0..100_000)
        .map(|n| format!("n{:06}", 999_999 - n))
        .collect();
    let src = format!("<html><body><html {}>x", names.join(" "));
    names.sort();
    let started = std::time::Instant::now();
    let built = build_document(&src, 200_000, None, || true).ok().unwrap();
    assert!(started.elapsed().as_secs() < 20, "{:?}", started.elapsed());
    let got: Vec<&str> = built
        .html
        .root_element()
        .value()
        .attrs()
        .map(|(n, _)| n)
        .collect();
    assert_eq!(got.len(), 100_000);
    assert!(got.windows(2).all(|w| w[0] < w[1]), "sorted and unique");
}

#[test]
fn the_attribute_slot_of_every_clone_is_charged() {
    // 20 000 five-character names, cloned 60 times: the names alone are small,
    // but each clone holds its own slots.
    let names: Vec<String> = (0..20_000).map(|n| format!("a{n:04}")).collect();
    let src = format!("<body><p><b {}></p>{}", names.join(" "), "<p>x".repeat(60));
    let (b, hit) = budget(16 * 1024 * 1024);
    let r = super::build_document(&src, 200_000, None, &b, || true);
    assert_eq!(r.err(), Some(BuildStop::OverBudget));
    assert!(hit.load(Ordering::SeqCst));
}

#[test]
fn the_budget_refusing_inside_an_attribute_merge_is_over_budget_and_fully_released() {
    // The first <html> has no attributes; the second one's attributes are
    // merged by `add_attrs_if_missing` and are more than the budget allows.
    let attrs: Vec<String> = (0..200)
        .map(|n| format!("n{n:03}=\"{}\"", "v".repeat(1000)))
        .collect();
    let src = format!("<html><body><html {}>x", attrs.join(" "));
    let (b, hit) = budget(100 * 1024);
    let r = super::build_document(&src, 200_000, None, &b, || true);
    assert_eq!(r.err(), Some(BuildStop::OverBudget));
    assert!(hit.load(Ordering::SeqCst));
    assert!(b.try_charge(100 * 1024), "the whole charge was given back");
}
