//! `Html.parse`: the selector API, its limits and the failure data of a run
//! that hits one.

mod plugin_common;

use std::time::{Duration, Instant};

use plugin_common::{answer_with, ok_response};
use plugin_common::{run_script, run_with_fetch, RunOptions};
use rust_lib_kanaru::api::plugin_runtime::{PluginScriptResult, PluginScriptStatus as S};

const PAGE: &str = include_str!("fixtures/plugin_runtime/genius_like_page.html");

/// Runs `body` as `execute()`, with the page in the global `PAGE`.
fn run(body: &str) -> PluginScriptResult {
    let page = js_string(PAGE);
    run_script(
        &format!("var PAGE = {page}; function execute() {{ {body} }}"),
        0,
    )
}

/// A JS string literal for `text` (no serde in this crate).
fn js_string(text: &str) -> String {
    let mut out = String::from("\"");
    for ch in text.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

fn ok(r: PluginScriptResult) -> String {
    assert_eq!(r.status, S::Ok, "{r:?}");
    r.output_json
}

#[test]
fn attribute_selector_finds_the_lyrics_blocks_and_text_keeps_the_lines() {
    let out = ok(run("var doc = Html.parse(PAGE);
         var parts = doc.select('div[data-lyrics-container=\"true\"]');
         return Response.success({ size: parts.size(), first: parts.first().text(),
           second: parts.get(1).text(), none: doc.selectFirst('table'), tag: parts.first().tagName() });"));
    assert_eq!(
        out,
        concat!(
            r#"{"size":2,"first":"[Verse 1]\nThe lamp is low, the kettle sings\nA paper boat on silver strings\n\n"#,
            r#"[Chorus]\nSail on, sail on, invented sea\nNobody wrote this line but me","#,
            r#""second":"[Verse 2]\nMorning folds the map in two\n& leaves a note: \"see you\"","#,
            r#""none":null,"tag":"div"}"#
        )
    );
}

#[test]
fn elements_text_joins_with_newlines_and_script_text_is_not_page_text() {
    let out = ok(run("var doc = Html.parse(PAGE);
         return Response.success({
           items: doc.select('ul.related li').text(),
           head: doc.selectFirst('head').text(),
           title: doc.selectFirst('title').text() });"));
    assert_eq!(
        out,
        r#"{"items":"Song One\nSong Two\nSong Three","head":"Invented Song Lyrics | Example Lyrics Site","title":"Invented Song Lyrics | Example Lyrics Site"}"#
    );
}

#[test]
fn attr_returns_empty_text_for_a_missing_attribute() {
    let out = ok(run(
        "var doc = Html.parse(PAGE);
         var a = doc.selectFirst('a.artist-link');
         return Response.success([a.attr('href'), a.attr('HREF'), a.attr('data-id'), a.attr('nope'),
           doc.select('ul.related a').attr('href'), doc.select('nothing').attr('href')]);",
    ));
    assert_eq!(
        out,
        r#"["/artists/example-band","/artists/example-band","42","","/songs/one",""]"#
    );
}

#[test]
fn map_for_each_to_array_and_scoped_select() {
    let out = ok(run(
        "var doc = Html.parse(PAGE);
         var links = doc.select('ul.related a');
         var hrefs = links.map(function (a, i) { return i + ':' + a.attr('href'); });
         var seen = []; links.forEach(function (a) { seen.push(a.text()); });
         var inner = doc.selectFirst('ul.related').select('a').size();
         var outside = doc.selectFirst('ul.related').select('h1').size();
         return Response.success({ hrefs: hrefs, seen: seen, arr: links.toArray().length,
           last: links.last().text(), get: links.get(7), inner: inner, outside: outside });",
    ));
    assert_eq!(
        out,
        r#"{"hrefs":["0:/songs/one","1:/songs/two","2:/songs/three"],"seen":["Song One","Song Two","Song Three"],"arr":3,"last":"Song Three","get":null,"inner":3,"outside":0}"#
    );
}

#[test]
fn html_and_outer_html_serialize_the_element() {
    let out = ok(run(
        "var p = Html.parse('<body><div id=a>x<b>y</b></div></body>').selectFirst('#a');
         return Response.success([p.html(), p.outerHtml(), p.tagName()]);",
    ));
    assert_eq!(
        out,
        r#"["x<b>y</b>","<div id=\"a\">x<b>y</b></div>","div"]"#
    );
}

#[test]
fn bad_selector_is_a_syntax_error_with_the_selector_text() {
    let out = ok(run("var doc = Html.parse(PAGE), name, message;
         try { doc.select('div[[oops'); } catch (e) { name = e.name; message = e.message; }
         var long = '', msg2;
         try { doc.select('(' + 'x'.repeat(300)); } catch (e) { msg2 = e.message; }
         var big;
         try { doc.select('a,'.repeat(600)); } catch (e) { big = e.name; }
         return Response.success([name, message.indexOf('div[[oops') >= 0, msg2.length < 400,
           msg2.indexOf('...') >= 0, big]);"));
    assert_eq!(out, r#"["SyntaxError",true,true,true,"SyntaxError"]"#);
}

#[test]
fn ninth_document_is_a_range_error_and_failed_parses_do_not_count() {
    let out = ok(run("var kept = [];
         for (var i = 0; i < 8; i++) kept.push(Html.parse('<p>' + i + '</p>'));
         var name, first;
         try { Html.parse('<p>9</p>'); } catch (e) { name = e.name; }
         first = kept[0].text() + kept[7].text();
         return Response.success([name, first, kept.length]);"));
    assert_eq!(out, r#"["RangeError","07",8]"#);
    // Oversized input never takes a slot.
    let out = ok(run("var big = 'x'.repeat(5 * 1024 * 1024), n = 0;
         for (var i = 0; i < 12; i++) { try { Html.parse(big); } catch (e) { n += e.name === 'RangeError' ? 1 : 0; } }
         return Response.success([n, Html.parse('<p>ok</p>').text()]);"));
    assert_eq!(out, r#"[12,"ok"]"#);
}

#[test]
fn five_mib_input_is_a_range_error_and_four_mib_parses() {
    let out = ok(run("var name;
         try { Html.parse('a'.repeat(5 * 1024 * 1024)); } catch (e) { name = e.name; }
         var edge = Html.parse('<p>' + 'a'.repeat(4 * 1024 * 1024 - 7) + '</p>').text().length;
         return Response.success([name, edge]);"));
    assert_eq!(out, format!(r#"["RangeError",{}]"#, 4 * 1024 * 1024 - 7));
}

#[test]
fn nesting_up_to_the_depth_limit_works_and_one_level_more_is_refused() {
    // `<html>` is level 1 and `<body>` level 2, so 510 spans are level 512.
    let out = ok(run("var doc = Html.parse('<span>'.repeat(510) + 'deep' + '</span>'.repeat(510));
         var name, message;
         try { Html.parse('<span>'.repeat(511)); } catch (e) { name = e.name; message = e.message; }
         var spans = doc.select('span');
         return Response.success([doc.text(), spans.size(), spans.last().text(), doc.outerHtml().length > 510 * 13,
           name, message.indexOf('512') >= 0]);"));
    assert_eq!(out, r#"["deep",510,"deep",true,"RangeError",true]"#);
}

#[test]
fn deep_junk_is_refused_at_parse_with_a_catchable_range_error_and_the_run_goes_on() {
    let started = Instant::now();
    let r = run("var names = [];
         var junk = ['<span>'.repeat(90000), '<div>'.repeat(100000), '<b>'.repeat(5000),
                     '<blockquote>'.repeat(2000), '<div><b>'.repeat(3000)];
         for (var i = 0; i < junk.length; i++) {
           try { Html.parse(junk[i]); names.push('parsed'); } catch (e) { names.push(e.name); }
         }
         var ok = Html.parse('<p>fine</p>').text();
         return Response.success([names, ok]);");
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(
        r.output_json,
        r#"[["RangeError","RangeError","RangeError","RangeError","RangeError"],"fine"]"#
    );
    // Quick: the parse stops a few chunks in, long before the quadratic part.
    assert!(
        started.elapsed() < Duration::from_secs(30),
        "{:?}",
        started.elapsed()
    );
}

#[test]
fn has_and_descendant_selectors_cannot_reach_a_deep_tree() {
    let r = run("var name = 'none', msg = '';
         try {
           var d = Html.parse('<span>'.repeat(90000));
           d.select(':has(x)');
         } catch (e) { name = e.name; }
         console.log('caught ' + name);
         return Response.success(name);");
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(r.output_json, r#""RangeError""#);
    assert_eq!(r.logs, vec!["caught RangeError".to_owned()]);

    // On the deepest allowed chain the selectors stay cheap (log the time).
    let r = run("var d = Html.parse('<span>'.repeat(510));
         var t = Date.now();
         var a = d.select('x span').size(), b = d.select('span:has(x)').size(), c = d.select('span span span').size();
         console.log('select ms ' + (Date.now() - t));
         return Response.success([a, b, c]);");
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(r.output_json, "[0,0,508]");
    eprintln!("deepest allowed chain: {}", r.logs[0]);
}

#[test]
fn more_than_the_node_cap_is_a_range_error_and_the_call_ends_memory() {
    // 60 000 nodes stay under the cap; 220 000 do not. The refusal is
    // catchable, but the call ends `memory` like a byte budget overrun.
    let r = run("var doc = Html.parse('<i>x</i>'.repeat(30000));
         var a = doc.select('i').size();
         var name, size;
         try { Html.parse('<i>x</i>'.repeat(110000)); } catch (e) { name = e.name; size = e.message; }
         console.log(a + ' ' + name + ' ' + (size.indexOf('200000') >= 0));
         return Response.success('done');");
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_eq!(r.logs, vec!["30000 RangeError true".to_owned()], "{r:?}");
}

#[test]
fn many_oversized_documents_each_throw_and_the_call_ends_memory() {
    let r = run("var names = [];
         for (var i = 0; i < 8; i++) {
           try { Html.parse('<i>x</i>'.repeat(120000)); names.push('parsed'); }
           catch (e) { names.push(e.name); }
         }
         console.log(names.join());
         return Response.success(names);");
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_eq!(r.logs, vec![vec!["RangeError"; 8].join(",")], "{r:?}");
}

#[test]
fn documents_are_charged_to_the_shared_byte_budget() {
    // About 90 000 nodes per document: eight of them would be far above the
    // 16 MiB budget, so a later parse is refused and the call ends `memory`
    // even though the script catches the error.
    let r = run("var kept = [], name;
         try { for (var i = 0; i < 8; i++) kept.push(Html.parse('<i>x</i>'.repeat(45000))); }
         catch (e) { name = e.name; console.log('stopped at ' + kept.length + ' ' + name); }
         return Response.success(name);");
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_eq!(r.logs.len(), 1, "{r:?}");
    assert!(r.logs[0].starts_with("stopped at "), "{r:?}");
    assert!(r.logs[0].ends_with(" RangeError"), "{r:?}");
}

#[test]
fn unread_fetch_bodies_and_documents_share_one_budget() {
    // 12 MiB of unread body leaves too little for a 90 000 node document.
    let answerer = answer_with(|_| ok_response(200, &vec![b'x'; 12 * 1024 * 1024]));
    let r = run_with_fetch(
        "function execute() {
           var res = fetch('https://t.test/big');
           var name = 'none';
           try { Html.parse('<i>x</i>'.repeat(45000)); } catch (e) { name = e.name; }
           return Response.success(name);
         }",
        answerer,
        RunOptions::default(),
    );
    assert_eq!(r.status, S::Memory, "{r:?}");
}

#[test]
fn strings_with_lone_surrogates_are_a_type_error() {
    let out = ok(run("var names = [];
         try { Html.parse('<p>\\ud800</p>'); } catch (e) { names.push(e.name); }
         var doc = Html.parse('<p>ok</p>');
         try { doc.select('p\\udc00'); } catch (e) { names.push(e.name); }
         try { doc.selectFirst('p').attr('\\ud800'); } catch (e) { names.push(e.name); }
         return Response.success(names);"));
    assert_eq!(out, r#"["TypeError","TypeError","TypeError"]"#);
}

#[test]
fn a_script_cannot_construct_or_forge_elements() {
    let out = ok(run(
        "var el = Html.parse('<p>x</p>').selectFirst('p'), names = [];
         var C = el.constructor;
         try { new C(1, 0); } catch (e) { names.push(e.name); }
         try { new (el.select('p').constructor)({}, [0, 99999]); } catch (e) { names.push(e.name); }
         try { el.text.call({}); } catch (e) { names.push(e.name); }
         try { el.select.call(Html, 'p'); } catch (e) { names.push(e.name); }
         return Response.success([names, Object.keys(el).length, typeof Html.parse]);",
    ));
    assert_eq!(
        out,
        r#"[["TypeError","TypeError","TypeError","TypeError"],0,"function"]"#
    );
}

#[test]
fn documents_do_not_outlive_the_call() {
    // Each call starts with an empty arena: eight documents again, no leftovers.
    for _ in 0..3 {
        let out = ok(run("var kept = [];
             for (var i = 0; i < 8; i++) kept.push(Html.parse('<p>x</p>'));
             var name; try { Html.parse('<p>x</p>'); } catch (e) { name = e.name; }
             return Response.success(name);"));
        assert_eq!(out, r#""RangeError""#);
    }
}

#[test]
fn parsing_four_mib_is_fast() {
    // A 4 MiB text-heavy page: a few nodes, almost all text. It takes a few
    // milliseconds in a release build; the time is logged, not asserted.
    let r = run("var t = Date.now();
         var doc = Html.parse('<p>' + 'lorem ipsum '.repeat(Math.floor(4 * 1024 * 1024 / 12) - 2) + '</p>');
         var ms = Date.now() - t;
         console.log('parse ms ' + ms);
         return Response.success([doc.select('p').size(), ms >= 0]);");
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(r.output_json, "[1,true]");
    eprintln!("4 MiB parse: {}", r.logs[0]);
}

#[test]
fn a_deadline_between_selects_still_stops_the_call() {
    let r = run_script(
        "function execute() {
           var doc = Html.parse('<i>x</i>'.repeat(30000));
           while (true) { doc.select('i'); }
         }",
        300,
    );
    assert_eq!(r.status, S::Timeout, "{r:?}");
}

#[test]
fn failed_runs_keep_console_lines_and_the_js_error() {
    let r = run("console.log('before');
         var doc = Html.parse(PAGE);
         console.log('parsed ' + doc.tagName());
         doc.select('a[[');
         return Response.success(1);");
    assert_eq!(r.status, S::ScriptError, "{r:?}");
    assert_eq!(r.logs, vec!["before".to_owned(), "parsed html".to_owned()]);
    let js = r
        .js_error
        .as_ref()
        .unwrap_or_else(|| panic!("js_error, {r:?}"));
    assert!(js.message.contains("CSS selector 'a[['"), "{r:?}");

    let r = run("console.log('before');
         Html.parse('x'.repeat(5 * 1024 * 1024));");
    assert_eq!(r.status, S::ScriptError, "{r:?}");
    assert_eq!(r.logs, vec!["before".to_owned()]);
    let js = r
        .js_error
        .as_ref()
        .unwrap_or_else(|| panic!("js_error, {r:?}"));
    assert!(js.message.contains("larger than the limit"), "{r:?}");
}

#[test]
fn attr_tries_the_exact_name_then_lower_case_and_tag_names_keep_html5ever_casing() {
    let out = ok(run("var doc = Html.parse('<body><svg viewBox=\"0 0 1 1\" Width=3><foreignObject></foreignObject></svg><P CLASS=a>x</P></body>');
         var svg = doc.selectFirst('svg');
         return Response.success([svg.attr('viewBox'), svg.attr('viewbox'), svg.attr('width'), svg.attr('Width'),
           svg.attr('missing'), doc.selectFirst('foreignObject').tagName(), doc.selectFirst('p').tagName(),
           doc.selectFirst('p').attr('CLASS'), doc.tagName()]);"));
    assert_eq!(
        out,
        r#"["0 0 1 1","","3","3","","foreignObject","p","a","html"]"#
    );
}

#[test]
fn text_hides_noscript_keeps_pre_line_breaks_and_more_blocks_end_a_line() {
    let out = ok(run("var doc = Html.parse('<body><noscript><p>enable js</p></noscript>' +
           '<pre>one\\n   two\\nthree</pre>' +
           '<header>h</header><section>s</section><article>a</article><blockquote>q</blockquote>' +
           '<table><tr><td>x</td><td>y</td></tr><tr><td>z</td></tr></table><footer>f</footer></body>');
         return Response.success(doc.text());"));
    assert_eq!(out, r#""one\n   two\nthree\nh\ns\na\nq\nx y\nz\nf""#);
}

/// A document at the depth limit with tens of thousands of siblings: the
/// selectors below need minutes of matching on it.
const SLOW_DOCUMENT: &str =
    "var doc = Html.parse('<span>'.repeat(500) + '<span></span>'.repeat(40000));";

#[test]
fn selectors_that_need_minutes_end_by_the_deadline() {
    for selector in [
        "Array(146).fill('x span').join(',')",
        "':has(x span)'",
        "'span:has(x span), div:has(x span)'",
    ] {
        let started = Instant::now();
        let r = run_script(
            &format!(
                "function execute() {{ {SLOW_DOCUMENT} doc.select({selector}); return Response.success(1); }}"
            ),
            400,
        );
        assert_eq!(r.status, S::Timeout, "{selector}: {r:?}");
        // Load-tolerant margin: unguarded these ran for 40 to 100 seconds.
        assert!(
            started.elapsed() < Duration::from_secs(10),
            "{selector}: {:?}",
            started.elapsed()
        );
    }
}

#[test]
fn a_cancel_during_select_is_seen_promptly() {
    let job = rust_lib_kanaru::plugin_runtime::begin_job();
    let canceller = std::thread::spawn(move || {
        std::thread::sleep(Duration::from_millis(500));
        rust_lib_kanaru::plugin_runtime::cancel_job(job);
    });
    let started = Instant::now();
    let r = plugin_common::block_on(rust_lib_kanaru::plugin_runtime::run(
        plugin_common::request_with(
            job,
            vec![plugin_common::file(
                "search.js",
                &format!(
                    "function execute() {{ {SLOW_DOCUMENT} doc.select(Array(146).fill('x span').join(',')); return Response.success(1); }}"
                ),
            )],
            "{}",
            0,
        ),
    ));
    canceller.join().expect("canceller thread");
    assert_eq!(r.status, S::Cancelled, "{r:?}");
    assert!(
        started.elapsed() < Duration::from_secs(10),
        "{:?}",
        started.elapsed()
    );
}

#[test]
fn nested_has_is_a_syntax_error_with_a_fixed_reason() {
    let out = ok(run(
        "var doc = Html.parse('<p>x</p>'), name, message;
         try { doc.select(':has(:has(x))'); } catch (e) { name = e.name; message = e.message; }
         return Response.success([name, message.indexOf(':has(:has(x))') >= 0,
           message.indexOf('InvalidState') < 0, message.indexOf('Unexpected error') < 0]);",
    ));
    assert_eq!(out, r#"["SyntaxError",true,true,true]"#);
}

#[test]
fn html_of_clones_sharing_a_big_attribute_is_refused_not_fatal() {
    let r = run("var doc = Html.parse('<body><p><b title=' + 'a'.repeat(100000) + '></p>' + '<p>x'.repeat(100));
         var name = 'none', len = 0;
         try { len = doc.selectFirst('body').html().length; } catch (e) { name = e.name; }
         // Small outputs still work.
         var small = Html.parse('<p>x</p>').selectFirst('p').outerHtml();
         console.log(name + ' ' + (len > 0) + ' ' + small);
         return Response.success(1);");
    // 100 clones of 100 KB are 10 MB (inside the byte budget, so the parse
    // works): past the 4 MiB output cap.
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_eq!(
        r.logs,
        vec!["RangeError false <p>x</p>".to_owned()],
        "{r:?}"
    );
}

#[test]
fn class_scans_end_by_the_deadline() {
    // 3 elements with 512 KiB of class text each, probed by 190 alternatives:
    // hundreds of megabytes of scanning, charged by the byte.
    let started = Instant::now();
    let r = run_script(
        "function execute() {
           var big = 'a '.repeat(256 * 1024), html = '<body>';
           for (var i = 0; i < 3; i++) html += '<div class=\"' + big + '\"></div>';
           var doc = Html.parse(html);
           doc.select(Array.from({length: 170}, function (_, n) { return '.c' + n; }).join(','));
           return Response.success(1);
         }",
        60,
    );
    assert_eq!(r.status, S::Timeout, "{r:?}");
    assert!(
        started.elapsed() < Duration::from_secs(15),
        "{:?}",
        started.elapsed()
    );
}

#[test]
fn a_long_run_of_comments_is_walked_under_the_deadline() {
    // 150 000 comment nodes after the first <i>, probed 100 times over.
    let r = run_script(
        "function execute() {
           var doc = Html.parse('<body><i></i>' + '<!--c-->'.repeat(150000) + '<i></i></body>');
           doc.select(Array(100).fill('i:first-child').join(','));
           return Response.success(1);
         }",
        150,
    );
    assert!(matches!(r.status, S::Timeout | S::Memory), "{r:?}");
}

const NAMES: &str = "function names(n, desc) { var a = []; for (var i = 0; i < n; i++) {
       var k = desc ? (n - 1 - i) : i; a.push((1e7 + k).toString(36)); } return a; }";

#[test]
fn a_repeated_html_tag_with_many_attributes_is_not_quadratic() {
    let started = Instant::now();
    let r = run_script(
        &format!(
            "{NAMES} function execute() {{
               var s = '<html><body><html ' + names(140000, true).join(' ') + '>x';
               var doc = Html.parse(s);
               return Response.success(doc.select('body').size());
             }}"
        ),
        5000,
    );
    // Quadratic it took 31 s; the deadline or the result both come quickly.
    assert!(matches!(r.status, S::Ok | S::Timeout | S::Memory), "{r:?}");
    assert!(
        started.elapsed() < Duration::from_secs(20),
        "{:?}",
        started.elapsed()
    );
}

#[test]
fn clones_of_an_element_with_many_attributes_are_refused() {
    let r = run_script(
        &format!(
            "{NAMES} function execute() {{
               var s = '<body><p><b ' + names(50000).join(' ') + '></p>' + '<p>x'.repeat(60);
               var name = 'none';
               try {{ Html.parse(s); }} catch (e) {{ name = e.name; }}
               console.log(name);
               return Response.success(name);
             }}"
        ),
        0,
    );
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_eq!(r.logs, vec!["RangeError".to_owned()], "{r:?}");
}
