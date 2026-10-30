//! A failed run still returns what was captured before it: console lines, the
//! JavaScript error (message and stack) when there is one, the first fetch
//! failure and the changed storage map. One script per failure; the same
//! script prefix writes a log line, makes a failing fetch and changes storage.

mod plugin_common;

use std::thread;
use std::time::Duration;

use plugin_common::{
    answer_with, block_on, file, never_answers, ok_response, outcome_response, request_with,
    run_with_fetch, RunOptions,
};
use rust_lib_kanaru::api::plugin_runtime::{
    PluginFetchFailureKind, PluginFetchOutcome, PluginScriptResult, PluginScriptStatus as S,
};
use rust_lib_kanaru::plugin_runtime::{self, Answerer};

/// Answers `/fail` with a network error and everything else with 5 MiB.
fn answerer() -> Answerer {
    answer_with(|request| {
        if request.url.ends_with("/fail") {
            outcome_response(PluginFetchOutcome::Network)
        } else {
            ok_response(200, &vec![b'x'; 5 * 1024 * 1024])
        }
    })
}

/// The shared start of every script: log, fail one fetch, change storage.
fn script(body: &str) -> String {
    format!(
        "function execute() {{
           console.log('step one');
           console.error({{stage: 'two'}});
           try {{ fetch('https://t.test/fail'); }} catch (e) {{ console.log('caught ' + e.name); }}
           localStorage.setItem('seen', 'yes');
           {body}
         }}"
    )
}

/// What every failure must still carry.
fn assert_captured(r: &PluginScriptResult) {
    assert_eq!(
        r.logs,
        vec![
            "step one".to_owned(),
            r#"{"stage":"two"}"#.to_owned(),
            "caught NetworkError".to_owned()
        ],
        "logs, status {:?}",
        r.status
    );
    let failure = r
        .fetch_failure
        .as_ref()
        .unwrap_or_else(|| panic!("fetch_failure, {r:?}"));
    assert_eq!(failure.kind, PluginFetchFailureKind::Network, "{r:?}");
    assert_eq!(
        r.storage_json.as_deref(),
        Some(r#"{"seen":"yes"}"#),
        "{r:?}"
    );
}

fn run(body: &str, answerer: Answerer, timeout_ms: u32) -> PluginScriptResult {
    run_with_fetch(
        &script(body),
        answerer,
        RunOptions {
            timeout_ms,
            ..RunOptions::default()
        },
    )
}

fn assert_js_error(r: &PluginScriptResult) {
    let js = r
        .js_error
        .as_ref()
        .unwrap_or_else(|| panic!("js_error, {r:?}"));
    assert!(
        !js.message.is_empty() || r.status == S::Timeout || r.status == S::Cancelled,
        "{js:?}"
    );
    assert!(
        js.stack.contains("search.js:"),
        "stack with line numbers: {js:?}"
    );
}

#[test]
fn script_error_keeps_logs_js_error_and_fetch_failure() {
    let r = run("throw new TypeError('kaput');", answerer(), 0);
    assert_eq!(r.status, S::ScriptError, "{r:?}");
    assert_captured(&r);
    assert_js_error(&r);
    assert!(r.js_error.unwrap().message.contains("kaput"));
}

#[test]
fn timeout_keeps_logs_js_error_and_fetch_failure() {
    let r = run("while (true) {}", answerer(), 300);
    assert_eq!(r.status, S::Timeout, "{r:?}");
    assert_captured(&r);
    assert!(r.js_error.is_some());
}

#[test]
fn timeout_while_dart_never_answers_keeps_everything() {
    let calls = std::sync::Arc::new(std::sync::atomic::AtomicU32::new(0));
    let counter = calls.clone();
    let hanging_after_first: Answerer = std::sync::Arc::new(move |_request| {
        if counter.fetch_add(1, std::sync::atomic::Ordering::SeqCst) == 0 {
            Box::pin(async { outcome_response(PluginFetchOutcome::Network) })
        } else {
            Box::pin(std::future::pending())
        }
    });
    let r = run("fetch('https://t.test/hangs');", hanging_after_first, 300);
    assert_eq!(r.status, S::Timeout, "{r:?}");
    assert_captured(&r);
}

#[test]
fn heap_memory_keeps_logs_js_error_and_fetch_failure() {
    let r = run(
        "var a = []; while (true) a.push({x: a.length});",
        answerer(),
        0,
    );
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_captured(&r);
    assert!(r.js_error.is_some());
}

#[test]
fn the_rust_byte_budget_keeps_logs_js_error_and_fetch_failure() {
    let r = run(
        "var kept = []; for (var i = 0; i < 10; i++) kept.push(fetch('https://t.test/big'));",
        answerer(),
        0,
    );
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_captured(&r);
    assert_js_error(&r);
}

#[test]
fn stack_overflow_keeps_logs_js_error_and_fetch_failure() {
    let r = run(
        "function f() { return f() + 1; } return f();",
        answerer(),
        0,
    );
    assert_eq!(r.status, S::Stack, "{r:?}");
    assert_captured(&r);
    assert!(r.js_error.is_some());
}

#[test]
fn output_too_large_keeps_logs_and_fetch_failure_and_has_no_js_error() {
    let r = run(
        "return Response.success('x'.repeat(3 * 1024 * 1024));",
        answerer(),
        0,
    );
    assert_eq!(r.status, S::OutputTooLarge, "{r:?}");
    assert_captured(&r);
    assert_eq!(r.js_error, None);
}

#[test]
fn cancel_during_a_fetch_keeps_everything_captured_before() {
    let calls = std::sync::Arc::new(std::sync::atomic::AtomicU32::new(0));
    let counter = calls.clone();
    let hanging_after_first: Answerer = std::sync::Arc::new(move |_request| {
        if counter.fetch_add(1, std::sync::atomic::Ordering::SeqCst) == 0 {
            Box::pin(async { outcome_response(PluginFetchOutcome::Network) })
        } else {
            Box::pin(std::future::pending())
        }
    });
    let job = plugin_runtime::begin_job();
    let canceller = thread::spawn(move || {
        thread::sleep(Duration::from_millis(250));
        plugin_runtime::cancel_job(job);
    });
    let request = request_with(
        job,
        vec![file("search.js", &script("fetch('https://t.test/hangs');"))],
        "{}",
        0,
    );
    let r = block_on(plugin_runtime::run_with(request, hanging_after_first));
    canceller.join().unwrap();
    assert_eq!(r.status, S::Cancelled, "{r:?}");
    assert_captured(&r);
}

#[test]
fn abandoned_fetch_ends_cancelled_with_its_failure_and_the_earlier_data() {
    let answerer = answer_with(|request| {
        if request.url.ends_with("/fail") {
            outcome_response(PluginFetchOutcome::Network)
        } else {
            outcome_response(PluginFetchOutcome::Abandoned)
        }
    });
    let r = run("fetch('https://t.test/walked-away');", answerer, 0);
    assert_eq!(r.status, S::Cancelled, "{r:?}");
    assert_captured(&r);
    assert_js_error(&r);
}

#[test]
fn a_throwing_dart_callback_is_a_network_failure_even_when_uncaught() {
    let answerer: Answerer = std::sync::Arc::new(|request| {
        if request.url.ends_with("/fail") {
            Box::pin(async { outcome_response(PluginFetchOutcome::Network) })
        } else {
            Box::pin(async { panic!("dart threw") })
        }
    });
    let r = run("fetch('https://t.test/boom');", answerer, 0);
    assert_eq!(r.status, S::ScriptError, "{r:?}");
    assert_captured(&r);
    assert!(r.js_error.as_ref().unwrap().message.contains("network"));
    assert!(
        !format!("{r:?}").contains("dart threw"),
        "panic text is not kept"
    );
    // The pool keeps working.
    let ok = plugin_common::run_script("function execute() { return Response.success(1); }", 0);
    assert_eq!(ok.status, S::Ok);
}

#[test]
fn response_error_and_invalid_response_keep_everything_too() {
    let r = run(
        "return Response.error('nope', {kind: 'rateLimited', retryAfterSec: 9});",
        answerer(),
        0,
    );
    assert_eq!(r.status, S::ScriptError, "{r:?}");
    assert_captured(&r);
    let r = run("return 5;", answerer(), 0);
    assert_eq!(r.status, S::ScriptError, "{r:?}");
    assert_captured(&r);
}

#[test]
fn never_answering_dart_is_a_timeout_even_for_the_first_fetch() {
    let r = run_with_fetch(
        "function execute() { console.log('only line'); fetch('https://t.test/'); }",
        never_answers(),
        RunOptions {
            timeout_ms: 250,
            ..RunOptions::default()
        },
    );
    assert_eq!(r.status, S::Timeout, "{r:?}");
    assert_eq!(r.logs, vec!["only line".to_owned()]);
    assert_eq!(r.fetch_failure, None, "no outcome ever arrived");
}

#[test]
fn error_texts_stay_capped() {
    let r = run_with_fetch(
        "function execute() { console.log('x'); throw new Error('m'.repeat(5000)); }",
        answerer(),
        RunOptions::default(),
    );
    let js = r.js_error.unwrap();
    assert_eq!(js.message.chars().count(), 1000);
    assert!(js.stack.len() <= 16 * 1024);
}
