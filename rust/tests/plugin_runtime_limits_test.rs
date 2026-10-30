//! Hard limits of the plugin runtime: wall time, heap, stack, output size,
//! threads, queue. Tests that fill the shared worker pool run one at a time.

mod plugin_common;

use std::sync::atomic::AtomicBool;
use std::sync::{Arc, Mutex, MutexGuard};
use std::thread;
use std::time::{Duration, Instant};

use plugin_common::{block_on, file, request_with, run_script};
use rust_lib_kanaru::api::plugin_runtime::{PluginScriptResult, PluginScriptStatus as S};
use rust_lib_kanaru::plugin_runtime::{self, engine, limits};

/// The pool is shared by the whole process; a test that saturates it must not
/// overlap another test.
fn serial() -> MutexGuard<'static, ()> {
    static LOCK: Mutex<()> = Mutex::new(());
    LOCK.lock().unwrap_or_else(|e| e.into_inner())
}

const OK: &str = "function execute() { return Response.success('fine'); }";

/// A job after a failure must still run: the worker was freed.
fn assert_pool_still_works() {
    let r = run_script(OK, 0);
    assert_eq!(r.status, S::Ok, "{r:?}");
}

fn timed(code: &str, timeout_ms: u32) -> (PluginScriptResult, Duration) {
    let started = Instant::now();
    let r = run_script(code, timeout_ms);
    (r, started.elapsed())
}

/// Runs the job directly on a thread with the worker stack size and times it
/// there, so machine load on other threads does not skew the deadline check.
fn run_on_worker_thread(code: &str, timeout_ms: u64) -> (PluginScriptResult, Duration) {
    let spec = engine::JobSpec::new(
        [("search.js".to_owned(), code.to_owned())],
        "search.js".to_owned(),
        "{}".to_owned(),
        Duration::from_millis(timeout_ms),
        Arc::new(AtomicBool::new(false)),
    )
    .unwrap();
    thread::Builder::new()
        .stack_size(limits::THREAD_STACK_BYTES)
        .spawn(move || {
            let started = Instant::now();
            let r = engine::run_job(&spec);
            (r, started.elapsed())
        })
        .unwrap()
        .join()
        .unwrap()
}

#[test]
fn constants_match_the_documented_limits() {
    assert_eq!(limits::WORKER_THREADS, 4);
    assert_eq!(limits::QUEUE_CAPACITY, 16);
    assert_eq!(limits::MEMORY_LIMIT_BYTES, 32 * 1024 * 1024);
    assert_eq!(limits::SCRIPT_STACK_BYTES, 1024 * 1024);
    assert_eq!(limits::THREAD_STACK_BYTES, 8 * 1024 * 1024);
    assert_eq!(limits::WALL_TIME, Duration::from_secs(15));
    assert_eq!(limits::MAX_OUTPUT_BYTES, 2 * 1024 * 1024);
    assert_eq!(limits::MAX_FETCH_REQUEST_BODY_BYTES, 256 * 1024);
    assert_eq!(limits::MAX_FETCH_SENDS, 10);
    assert_eq!(limits::RUST_BYTE_BUDGET, 16 * 1024 * 1024);
    assert_eq!(limits::MAX_HTML_INPUT_BYTES, 4 * 1024 * 1024);
    assert_eq!(limits::MAX_HTML_DOCUMENTS, 8);
    assert_eq!(limits::MAX_HTML_NODES, 200_000);
    assert_eq!(limits::MAX_HTML_SELECTOR_BYTES, 1024);
    assert_eq!(limits::STORAGE_QUOTA_BYTES, 64 * 1024);
    assert_eq!(limits::MAX_LOG_LINES, 50);
    assert_eq!(limits::MAX_LOG_LINE_CHARS, 500);
    assert_eq!(limits::CANCEL_POLL, Duration::from_millis(50));
}

#[test]
fn infinite_loop_times_out_on_the_deadline() {
    let _s = serial();
    for deadline_ms in [150u64, 400] {
        let (r, took) = run_on_worker_thread("function execute() { while (true) {} }", deadline_ms);
        assert_eq!(r.status, S::Timeout, "{r:?}");
        let limit = Duration::from_millis(deadline_ms);
        assert!(took >= limit, "{took:?}");
        assert!(
            took < limit + Duration::from_millis(100),
            "stopped late: {took:?}"
        );
    }
    assert_pool_still_works();
}

#[test]
fn a_loop_inside_try_catch_cannot_swallow_the_timeout() {
    let _s = serial();
    let code =
        "function execute() { for (;;) { try { while (true) {} } catch (e) {} finally {} } }";
    let (r, took) = run_on_worker_thread(code, 200);
    assert_eq!(r.status, S::Timeout, "{r:?}");
    assert!(took < Duration::from_millis(300), "{took:?}");
}

#[test]
fn catastrophic_regex_times_out() {
    let _s = serial();
    let code =
        "function execute() { return Response.success(/(a+)+$/.test('a'.repeat(40) + 'b')); }";
    let (r, took) = run_on_worker_thread(code, 300);
    assert_eq!(r.status, S::Timeout, "{r:?}");
    assert!(took < Duration::from_millis(400), "{took:?}");
    assert_pool_still_works();
}

#[test]
fn a_timeout_is_also_found_while_loading_a_file() {
    let _s = serial();
    let job = plugin_runtime::begin_job();
    let started = Instant::now();
    let r = block_on(plugin_runtime::run(request_with(
        job,
        vec![
            file("search.js", "load('spin.js'); function execute() {}"),
            file("spin.js", "while (true) {}"),
        ],
        "{}",
        200,
    )));
    assert_eq!(r.status, S::Timeout, "{r:?}");
    assert!(started.elapsed() < Duration::from_millis(200 + 350));
}

#[test]
fn huge_heap_is_a_memory_error() {
    let _s = serial();
    // 64 MiB of array elements does not fit in the 32 MiB heap.
    let code = "function execute() { var a = new Array(8 * 1024 * 1024); for (var i = 0; i < a.length; i++) a[i] = i * 1.5; return Response.success(a.length); }";
    let r = run_script(code, 0);
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_pool_still_works();

    let code = "function execute() { var a = []; for (;;) a.push('x' + a.length); }";
    assert_eq!(run_script(code, 0).status, S::Memory);

    let code = "function execute() { var s = 'x'; for (;;) s += s; }";
    let r = run_script(code, 0);
    // A string that cannot be built is either an out-of-memory or a RangeError the engine throws.
    assert!(matches!(r.status, S::Memory | S::ScriptError), "{r:?}");
    assert_pool_still_works();
}

#[test]
fn deep_recursion_is_a_stack_error_not_a_crash() {
    let _s = serial();
    let cases = [
        // plain JS recursion
        "function execute() { function f(n) { return f(n + 1) + 1; } return Response.success(f(0)); }",
        // mutual recursion through method calls and closures
        "function execute() { var o = { m: function (n) { return [n].map(function (x) { return o.m(x + 1); })[0]; } }; return Response.success(o.m(0)); }",
        // recursion inside native code: toString of nested arrays
        "function execute() { var a = []; for (var i = 0; i < 200000; i++) a = [a]; return Response.success(String(a)); }",
        // recursion inside the native JSON parser
        "function execute() { return Response.success(JSON.parse('['.repeat(500000) + ']'.repeat(500000))); }",
        // recursion inside the native JSON serializer
        "function execute() { var a = []; for (var i = 0; i < 200000; i++) a = [a]; return Response.success(JSON.stringify(a)); }",
        // recursion through getters and toString hooks
        "function execute() { var o = { get x() { return this.x; } }; return Response.success(o.x); }",
        "function execute() { var o = {}; o.toString = function () { return '' + o; }; return Response.success('' + o); }",
        // recursion through Array.prototype.sort and apply
        "function execute() { function f() { [2, 1].sort(f); } f(); }",
        "function execute() { function f() { return f.apply(null, []); } return Response.success(f()); }",
        // recursion in the parser of eval and new Function
        "function execute() { return Response.success(eval('('.repeat(300000) + '1' + ')'.repeat(300000))); }",
        "function execute() { return Response.success(new Function('return ' + '['.repeat(300000) + ']'.repeat(300000))()); }",
    ];
    for (n, code) in cases.iter().enumerate() {
        let r = run_script(code, 3000);
        assert!(
            matches!(r.status, S::Stack | S::ScriptError),
            "case {n} must fail cleanly: {r:?}"
        );
        if n < 9 {
            assert_eq!(r.status, S::Stack, "case {n}: {r:?}");
        }
        assert_pool_still_works();
    }
}

#[test]
fn recursion_that_catches_the_stack_error_ends_by_deadline_not_crash() {
    let _s = serial();
    let code = "function execute() { function g() { try { g(); } catch (e) { g(); } } g(); }";
    let r = run_script(code, 500);
    assert!(matches!(r.status, S::Timeout | S::Stack), "{r:?}");
    assert_pool_still_works();
}

#[test]
fn output_over_two_mib_is_refused_and_at_the_limit_is_fine() {
    let _s = serial();
    let r = run_script(
        "function execute() { return Response.success('x'.repeat(3 * 1024 * 1024)); }",
        0,
    );
    assert_eq!(r.status, S::OutputTooLarge, "{r:?}");
    assert_eq!(r.output_json, "");

    // The JSON text of this string is exactly 2 MiB (content plus two quotes).
    let at_limit = format!(
        "function execute() {{ return Response.success('x'.repeat({})); }}",
        limits::MAX_OUTPUT_BYTES - 2
    );
    let r = run_script(&at_limit, 0);
    assert_eq!(r.status, S::Ok, "{:?}", r.status);
    assert_eq!(r.output_json.len(), limits::MAX_OUTPUT_BYTES);

    let over = format!(
        "function execute() {{ return Response.success('x'.repeat({})); }}",
        limits::MAX_OUTPUT_BYTES - 1
    );
    assert_eq!(run_script(&over, 0).status, S::OutputTooLarge);
}

#[test]
fn unserializable_data_is_a_script_error() {
    let _s = serial();
    let r = run_script(
        "function execute() { var a = {}; a.self = a; return Response.success(a); }",
        0,
    );
    assert_eq!(r.status, S::ScriptError, "{r:?}");
    assert!(r.js_error.is_some());
    let r = run_script("function execute() { return Response.success(10n); }", 0);
    assert_eq!(r.status, S::ScriptError, "{r:?}");
}

#[test]
fn five_jobs_run_in_parallel_on_four_threads() {
    let _s = serial();
    let started = Instant::now();
    let handles: Vec<_> = (0..5)
        .map(|n| {
            thread::spawn(move || {
                run_script(
                    &format!("function execute() {{ var end = Date.now() + 300; while (Date.now() < end) {{}} return Response.success({n}); }}"),
                    0,
                )
            })
        })
        .collect();
    let results: Vec<_> = handles.into_iter().map(|h| h.join().unwrap()).collect();
    let took = started.elapsed();
    for (n, r) in results.iter().enumerate() {
        assert_eq!(r.status, S::Ok, "{r:?}");
        assert_eq!(r.output_json, n.to_string());
    }
    // Serial would take 1500 ms; four at once plus one more takes about 600 ms.
    assert!(
        took < Duration::from_millis(1300),
        "no parallelism: {took:?}"
    );
}

#[test]
fn seventeenth_queued_job_is_busy_and_cancelling_frees_the_workers() {
    let _s = serial();
    let capacity = limits::WORKER_THREADS + limits::QUEUE_CAPACITY;
    let spin = "function execute() { while (true) {} }";
    let ids: Vec<u32> = (0..capacity).map(|_| plugin_runtime::begin_job()).collect();
    let handles: Vec<_> = ids
        .iter()
        .map(|&id| {
            thread::spawn(move || {
                block_on(plugin_runtime::run(request_with(
                    id,
                    vec![file("search.js", spin)],
                    "{}",
                    0,
                )))
            })
        })
        .collect();
    thread::sleep(Duration::from_millis(600)); // 4 running, 16 queued

    let started = Instant::now();
    let busy = run_script(OK, 0);
    assert_eq!(busy.status, S::Busy, "{busy:?}");
    assert!(
        started.elapsed() < Duration::from_millis(250),
        "busy must answer at once"
    );
    assert_eq!(busy.js_error, None);
    assert!(!busy.error_message.is_empty());

    for &id in &ids {
        plugin_runtime::cancel_job(id);
    }
    for h in handles {
        let r = h.join().unwrap();
        assert_eq!(r.status, S::Cancelled, "{r:?}");
    }
    assert_pool_still_works();
}

#[test]
fn timed_out_and_cancelled_jobs_free_their_workers() {
    let _s = serial();
    // More failing jobs than threads, back to back: each one must release its worker.
    for _ in 0..limits::WORKER_THREADS * 2 {
        let (r, _) = timed("function execute() { while (true) {} }", 100);
        assert_eq!(r.status, S::Timeout);
    }
    for _ in 0..limits::WORKER_THREADS * 2 {
        let id = plugin_runtime::begin_job();
        let canceller = thread::spawn(move || {
            thread::sleep(Duration::from_millis(50));
            plugin_runtime::cancel_job(id);
        });
        let r = block_on(plugin_runtime::run(request_with(
            id,
            vec![file("search.js", "function execute() { while (true) {} }")],
            "{}",
            0,
        )));
        canceller.join().unwrap();
        assert_eq!(r.status, S::Cancelled);
    }
    assert_pool_still_works();
}

#[test]
fn cancel_of_a_running_job_is_seen_promptly() {
    let _s = serial();
    let id = plugin_runtime::begin_job();
    let (tx, rx) = std::sync::mpsc::channel();
    let runner = thread::spawn(move || {
        let r = block_on(plugin_runtime::run(request_with(
            id,
            vec![file("search.js", "function execute() { while (true) {} }")],
            "{}",
            0,
        )));
        tx.send(Instant::now()).unwrap();
        r
    });
    thread::sleep(Duration::from_millis(200));
    let cancelled_at = Instant::now();
    plugin_runtime::cancel_job(id);
    let finished_at = rx.recv_timeout(Duration::from_secs(5)).expect("job ended");
    assert_eq!(runner.join().unwrap().status, S::Cancelled);
    assert!(finished_at.duration_since(cancelled_at) < Duration::from_millis(350));
}

#[test]
fn dropping_the_call_stops_the_worker() {
    let _s = serial();
    // Fill all four workers with endless jobs whose callers go away; the
    // workers must come back without waiting for the 15 s deadline.
    for _ in 0..limits::WORKER_THREADS {
        let id = plugin_runtime::begin_job();
        let mut fut = Box::pin(plugin_runtime::run(request_with(
            id,
            vec![file("search.js", "function execute() { while (true) {} }")],
            "{}",
            0,
        )));
        // Poll once so the job is queued, then drop the future.
        let waker = std::task::Waker::noop();
        let mut cx = std::task::Context::from_waker(waker);
        let _ = std::future::Future::poll(fut.as_mut(), &mut cx);
        drop(fut);
    }
    let started = Instant::now();
    assert_pool_still_works();
    assert!(
        started.elapsed() < Duration::from_secs(2),
        "workers were not released"
    );
}

#[test]
fn cancelling_queued_jobs_ends_them_at_once_and_frees_their_slots() {
    let _s = serial();
    let capacity = limits::WORKER_THREADS + limits::QUEUE_CAPACITY;
    let spin = "function execute() { while (true) {} }";
    let ids: Vec<u32> = (0..capacity).map(|_| plugin_runtime::begin_job()).collect();
    let (tx, rx) = std::sync::mpsc::channel();
    let mut handles = Vec::new();
    // The first four start running; the rest wait in the queue.
    for (n, &id) in ids.iter().enumerate() {
        let tx = tx.clone();
        handles.push(thread::spawn(move || {
            let r = block_on(plugin_runtime::run(request_with(
                id,
                vec![file("search.js", spin)],
                "{}",
                0,
            )));
            tx.send((n, Instant::now())).unwrap();
            r
        }));
        thread::sleep(Duration::from_millis(30)); // keep the submit order stable
    }
    thread::sleep(Duration::from_millis(400));
    assert_eq!(run_script(OK, 0).status, S::Busy, "pool is full");

    // Cancel only the waiting ones (the last sixteen submitted).
    let cancelled_at = Instant::now();
    for &id in &ids[limits::WORKER_THREADS..] {
        plugin_runtime::cancel_job(id);
    }
    let mut ended = 0;
    while ended < limits::QUEUE_CAPACITY {
        let (n, at) = rx
            .recv_timeout(Duration::from_secs(5))
            .expect("queued job ended");
        assert!(n >= limits::WORKER_THREADS, "a running job ended: {n}");
        assert!(
            at.duration_since(cancelled_at) < Duration::from_millis(350),
            "slow: {:?}",
            at.duration_since(cancelled_at)
        );
        ended += 1;
    }
    // The slots are free: a new job queues instead of being Busy.
    let id = plugin_runtime::begin_job();
    let waiting = thread::spawn(move || {
        block_on(plugin_runtime::run(request_with(
            id,
            vec![file("search.js", OK)],
            "{}",
            0,
        )))
    });
    thread::sleep(Duration::from_millis(250));
    assert!(
        !waiting.is_finished(),
        "the new job is queued behind the spinners, not Busy"
    );

    for &id in &ids[..limits::WORKER_THREADS] {
        plugin_runtime::cancel_job(id);
    }
    assert_eq!(waiting.join().unwrap().status, S::Ok);
    for (n, h) in handles.into_iter().enumerate() {
        assert_eq!(h.join().unwrap().status, S::Cancelled, "job {n}");
    }
}
