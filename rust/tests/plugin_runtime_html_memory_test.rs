//! Peak memory of `Html.parse` and `html()` on hostile input. One test in its
//! own test binary: the cases run one after the other in a single thread of
//! the test, and before each one the process' peak resident size is reset
//! (`/proc/self/clear_refs`), so a case is judged by its own peak. The
//! memory checks are skipped where `/proc` cannot do that.

mod plugin_common;

use plugin_common::run_script;
use rust_lib_kanaru::api::plugin_runtime::{PluginScriptResult, PluginScriptStatus as S};

fn status_kib(key: &str) -> Option<u64> {
    let status = std::fs::read_to_string("/proc/self/status").ok()?;
    let line = status.lines().find(|l| l.starts_with(key))?;
    line.split_whitespace().nth(1)?.parse().ok()
}

/// Runs `code` and returns its result and how far the peak resident size
/// rose above the size before it (KiB); `None` when the peak cannot be reset.
fn run_measured(code: &str) -> (PluginScriptResult, Option<u64>) {
    // "5" resets the peak resident size (VmHWM) to the current size.
    let reset = std::fs::write("/proc/self/clear_refs", "5").is_ok();
    let base = status_kib("VmRSS:");
    let r = run_script(code, 0);
    let growth = match (reset, base, status_kib("VmHWM:")) {
        (true, Some(base), Some(peak)) => Some(peak.saturating_sub(base)),
        _ => None,
    };
    (r, growth)
}

fn assert_below(growth: Option<u64>, case: &str, mib: u64) {
    if let Some(kib) = growth {
        eprintln!("{case}: peak RSS growth {} MiB", kib / 1024);
        assert!(
            kib / 1024 < mib,
            "{case}: peak RSS grew by {} MiB",
            kib / 1024
        );
    }
}

#[test]
fn hostile_documents_stay_inside_their_memory_bounds() {
    // 1. Eight documents over the node cap. The parser stops at the cap, so a
    // parse peaks near a 200 000 node tree (tens of MiB), not at the input's
    // size in nodes, and the eight do not add up. The node cap counts as a
    // budget overrun: the call ends `memory` although every error is caught.
    let (r, growth) = run_measured(
        "function execute() {
           var names = [];
           for (var i = 0; i < 8; i++) {
             try { Html.parse('<i>x</i>'.repeat(120000)); names.push('parsed'); }
             catch (e) { names.push(e.name); }
           }
           console.log(names.join());
           return Response.success(names);
         }",
    );
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_eq!(r.logs, vec![vec!["RangeError"; 8].join(",")], "{r:?}");
    assert_below(growth, "eight documents over the node cap", 160);

    // 2. Formatting element reconstruction: 500 distinct open `<b id=k>`
    // (under the depth limit), then `<p>x` over and over. html5ever clones
    // every open formatting element at each `<p>`, so a few kilobytes of input
    // would make millions of nodes without a bound inside the parser (296 MB
    // peak and several seconds in the measured case with 10 000 elements).
    let started = std::time::Instant::now();
    let (r, growth) = run_measured(
        "function execute() {
           var s = '<body><p>';
           for (var i = 0; i < 500; i++) s += '<b id=' + i + '>';
           s += '</p>';
           while (s.length < 1024 * 1024) s += '<p>x';
           var name = 'parsed';
           try { Html.parse(s); } catch (e) { name = e.name; }
           console.log(name);
           return Response.success(name);
         }",
    );
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_eq!(r.logs, vec!["RangeError".to_owned()], "{r:?}");
    // Load-tolerant: the unbounded parse took seconds alone.
    assert!(started.elapsed().as_secs() < 60, "{:?}", started.elapsed());
    assert_below(growth, "formatting amplification", 160);

    // 3. Clones that share one big attribute buffer: html5ever shares the
    // buffer, but the matcher and the serializer see every clone's copy in
    // full. 27 000 clones of a 3 MB value would be 81 GB; the attribute text
    // of every created element is charged to the byte budget, so the parse
    // ends at the budget (a few clones in).
    let started = std::time::Instant::now();
    let (r, growth) = run_measured(
        "function execute() {
           var name = 'none';
           try {
             Html.parse('<body><p><b title=' + 'a'.repeat(3000000) + '></p>' + '<p>x'.repeat(27000));
           } catch (e) { name = e.name; }
           console.log(name);
           return Response.success(name);
         }",
    );
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_eq!(r.logs, vec!["RangeError".to_owned()], "{r:?}");
    assert!(started.elapsed().as_secs() < 60, "{:?}", started.elapsed());
    assert_below(growth, "clones sharing a big attribute", 200);
}
