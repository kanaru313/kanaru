//! Helpers shared by the plugin runtime tests: a tiny executor and request
//! builders. The runtime needs no async runtime of its own, so neither do the tests.

#![allow(dead_code)]

use std::future::Future;
use std::sync::Arc;
use std::task::{Context, Poll, Wake, Waker};
use std::thread;
use std::time::{Duration, Instant};

use rust_lib_kanaru::api::plugin_runtime::{
    PluginScriptRequest, PluginScriptResult, PluginSourceFile,
};
use rust_lib_kanaru::plugin_runtime;

struct ThreadWaker(thread::Thread);
impl Wake for ThreadWaker {
    fn wake(self: Arc<Self>) {
        self.0.unpark();
    }
}

/// Minimal executor, bounded so a bug cannot hang the run.
pub fn block_on<T>(fut: impl Future<Output = T>) -> T {
    let mut fut = Box::pin(fut);
    let waker = Waker::from(Arc::new(ThreadWaker(thread::current())));
    let mut cx = Context::from_waker(&waker);
    let end = Instant::now() + Duration::from_secs(120);
    loop {
        if let Poll::Ready(v) = fut.as_mut().poll(&mut cx) {
            return v;
        }
        assert!(Instant::now() < end, "future did not finish in time");
        thread::park_timeout(Duration::from_millis(5));
    }
}

pub fn file(name: &str, code: &str) -> PluginSourceFile {
    PluginSourceFile {
        name: name.to_owned(),
        code: code.to_owned(),
    }
}

pub fn request_with(
    job: u32,
    files: Vec<PluginSourceFile>,
    input_json: &str,
    timeout_ms: u32,
) -> PluginScriptRequest {
    PluginScriptRequest {
        job,
        files,
        entry: "search.js".to_owned(),
        input_json: input_json.to_owned(),
        timeout_ms,
    }
}

/// Runs `code` as `search.js` with input `{}` as a new job.
pub fn run_script(code: &str, timeout_ms: u32) -> PluginScriptResult {
    let job = plugin_runtime::begin_job();
    block_on(plugin_runtime::run(request_with(
        job,
        vec![file("search.js", code)],
        "{}",
        timeout_ms,
    )))
}

/// Runs several files; `search.js` is the entry.
pub fn run_files(files: Vec<PluginSourceFile>, input_json: &str) -> PluginScriptResult {
    let job = plugin_runtime::begin_job();
    block_on(plugin_runtime::run(request_with(job, files, input_json, 0)))
}
