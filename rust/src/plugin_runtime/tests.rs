//! Unit tests that need the test-only host functions (`__testLog`,
//! `__testPanic`), which exist only in this crate's own test build.

use std::future::Future;
use std::sync::Arc;
use std::task::{Context, Poll, Wake, Waker};
use std::thread;
use std::time::{Duration, Instant};

use super::*;
use crate::api::plugin_runtime::{
    PluginErrorKind, PluginScriptRequest, PluginScriptResult, PluginScriptStatus as S,
    PluginSourceFile,
};

struct ThreadWaker(thread::Thread);
impl Wake for ThreadWaker {
    fn wake(self: Arc<Self>) {
        self.0.unpark();
    }
}

/// Minimal executor, bounded so a bug cannot hang the run.
fn block_on<T>(fut: impl Future<Output = T>) -> T {
    let mut fut = Box::pin(fut);
    let waker = Waker::from(Arc::new(ThreadWaker(thread::current())));
    let mut cx = Context::from_waker(&waker);
    let end = Instant::now() + Duration::from_secs(60);
    loop {
        if let Poll::Ready(v) = fut.as_mut().poll(&mut cx) {
            return v;
        }
        assert!(Instant::now() < end, "future did not finish");
        thread::park_timeout(Duration::from_millis(5));
    }
}

fn request(job: u32, code: &str, timeout_ms: u32) -> PluginScriptRequest {
    PluginScriptRequest {
        job,
        files: vec![PluginSourceFile {
            name: "search.js".to_owned(),
            code: code.to_owned(),
        }],
        entry: "search.js".to_owned(),
        input_json: "{}".to_owned(),
        timeout_ms,
        config: Vec::new(),
        storage_json: String::new(),
    }
}

fn run_script(code: &str, timeout_ms: u32) -> PluginScriptResult {
    block_on(run(request(begin_job(), code, timeout_ms)))
}

/// Every failing script writes a console line first; the line must come back.
fn script_with_log(body: &str) -> String {
    format!("function execute(input) {{ __testLog('before'); {body} }}")
}

fn assert_logged(r: &PluginScriptResult) {
    assert_eq!(r.logs, vec!["before".to_owned()], "status {:?}", r.status);
    assert_eq!(r.fetch_failure, None);
}

#[test]
fn logs_survive_a_success() {
    let r = run_script(&script_with_log("return Response.success([1]);"), 0);
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_logged(&r);
}

#[test]
fn logs_survive_a_thrown_error_with_message_and_stack() {
    let r = run_script(&script_with_log("throw new Error('kaput');"), 0);
    assert_eq!(r.status, S::ScriptError);
    assert_logged(&r);
    let js = r.js_error.expect("js_error on scriptError");
    assert!(js.message.contains("kaput"), "{js:?}");
    assert!(
        js.stack.contains("search.js:"),
        "stack keeps line numbers: {js:?}"
    );
}

#[test]
fn logs_and_js_error_survive_a_timeout() {
    let r = run_script(&script_with_log("while (true) {}"), 200);
    assert_eq!(r.status, S::Timeout);
    assert_logged(&r);
    assert!(r.js_error.is_some(), "the interrupt exception is reported");
    assert!(r.error_message.contains("200 ms"), "{}", r.error_message);
}

#[test]
fn logs_and_js_error_survive_the_memory_limit() {
    let r = run_script(
        &script_with_log("var a = []; while (true) a.push({x: a.length});"),
        0,
    );
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_logged(&r);
    assert!(r.js_error.is_some());
}

#[test]
fn logs_and_js_error_survive_the_stack_limit() {
    let r = run_script(
        &script_with_log("function f() { return f() + 1; } return f();"),
        0,
    );
    assert_eq!(r.status, S::Stack, "{r:?}");
    assert_logged(&r);
    assert!(r.js_error.is_some());
}

#[test]
fn logs_survive_output_too_large_and_it_has_no_js_error() {
    let r = run_script(
        &script_with_log("return Response.success('x'.repeat(3 * 1024 * 1024));"),
        0,
    );
    assert_eq!(r.status, S::OutputTooLarge, "{r:?}");
    assert_logged(&r);
    assert_eq!(r.js_error, None, "found by the host after execute returned");
    assert!(!r.error_message.is_empty());
}

#[test]
fn logs_survive_a_response_error_and_an_invalid_response() {
    let r = run_script(
        &script_with_log(
            "return Response.error('slow down', {kind: 'rateLimited', retryAfterSec: 7});",
        ),
        0,
    );
    assert_eq!(r.status, S::ScriptError);
    assert_eq!(r.error_kind, PluginErrorKind::RateLimited);
    assert_eq!(r.retry_after_sec, Some(7));
    assert_logged(&r);

    let r = run_script(&script_with_log("return {ok: true, data: 1};"), 0);
    assert_eq!(r.status, S::ScriptError);
    assert_eq!(r.error_kind, PluginErrorKind::InvalidResponse);
    assert_logged(&r);
}

#[test]
fn logs_and_js_error_survive_a_cancel_while_running() {
    let id = begin_job();
    let canceller = thread::spawn(move || {
        thread::sleep(Duration::from_millis(150));
        cancel_job(id);
    });
    let r = block_on(run(request(id, &script_with_log("while (true) {}"), 0)));
    canceller.join().unwrap();
    assert_eq!(r.status, S::Cancelled);
    assert_logged(&r);
    assert!(r.js_error.is_some(), "the interrupt exception is reported");
}

#[test]
fn a_panic_in_a_host_function_is_internal_keeps_logs_and_the_pool_runs_on() {
    let r = run_script(&script_with_log("__testPanic();"), 0);
    assert_eq!(r.status, S::Internal, "{r:?}");
    assert_logged(&r);
    assert_eq!(r.js_error, None);

    // Every worker stays usable: run more jobs than there are threads.
    for n in 0..limits::WORKER_THREADS * 2 {
        let r = run_script(
            &format!("function execute() {{ return Response.success({n}); }}"),
            0,
        );
        assert_eq!(r.status, S::Ok, "job {n} after the panic: {r:?}");
        assert_eq!(r.output_json, n.to_string());
    }
}

#[test]
fn cancelled_before_start_has_no_js_error_but_an_explanation() {
    let id = begin_job();
    cancel_job(id);
    let r = block_on(run(request(id, "function execute() {}", 0)));
    assert_eq!(r.status, S::Cancelled);
    assert_eq!(r.js_error, None);
    assert!(!r.error_message.is_empty());
    assert!(r.logs.is_empty());
}

#[test]
fn a_panic_in_an_html_native_is_internal_even_when_the_script_catches_it() {
    let r = run_script(
        &script_with_log(
            "var d = Html.parse('<p>x</p>'), caught = '';
             try { d.select('__panic__'); } catch (e) { caught = e.message; }
             return Response.success(caught);",
        ),
        0,
    );
    assert_eq!(r.status, S::Internal, "{r:?}");
    assert_logged(&r);
    // The pool still works.
    let r = run_script(
        "function execute() { return Response.success(Html.parse('<p>y</p>').text()); }",
        0,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(r.output_json, r#""y""#);
}

#[test]
fn a_heap_overflow_the_script_catches_still_ends_memory() {
    let r = run_script(
        &script_with_log(
            "var a = [];
             try { while (true) a.push({x: a.length, y: 'padding padding'}); } catch (e) {}
             a = null;
             return Response.success('recovered');",
        ),
        0,
    );
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_logged(&r);
}
