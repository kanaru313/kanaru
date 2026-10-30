//! Helpers shared by the plugin runtime tests: a tiny executor and request
//! builders. The runtime needs no async runtime of its own, so neither do the tests.

#![allow(dead_code)]

use std::future::Future;
use std::sync::Arc;
use std::task::{Context, Poll, Wake, Waker};
use std::thread;
use std::time::{Duration, Instant};

use rust_lib_kanaru::api::plugin_runtime::{
    PluginFetchOutcome, PluginFetchRequest, PluginFetchResponse, PluginScriptRequest,
    PluginScriptResult, PluginSourceFile,
};
use rust_lib_kanaru::plugin_runtime::{self, Answerer};

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
        config: Vec::new(),
        storage_json: String::new(),
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

/// An `ok` answer with `body`, one send.
pub fn ok_response(status: u16, body: &[u8]) -> PluginFetchResponse {
    PluginFetchResponse {
        status,
        body: body.to_vec(),
        url: "https://example.test/final".to_owned(),
        sends: 1,
        ..plugin_runtime::failed_response(PluginFetchOutcome::Ok)
    }
}

/// An answer that is not `ok`.
pub fn outcome_response(outcome: PluginFetchOutcome) -> PluginFetchResponse {
    plugin_runtime::failed_response(outcome)
}

/// An answerer from a plain function; the answer is ready at once.
pub fn answer_with(
    f: impl Fn(PluginFetchRequest) -> PluginFetchResponse + Send + Sync + 'static,
) -> Answerer {
    Arc::new(move |request| {
        let answer = f(request);
        Box::pin(async move { answer })
    })
}

/// An answerer whose future never completes (Dart that never replies).
pub fn never_answers() -> Answerer {
    Arc::new(|_request| Box::pin(std::future::pending()))
}

/// Everything a run can be given besides the code.
pub struct RunOptions {
    pub config: Vec<(String, String)>,
    pub storage_json: String,
    pub timeout_ms: u32,
}

impl Default for RunOptions {
    fn default() -> Self {
        Self {
            config: Vec::new(),
            storage_json: String::new(),
            timeout_ms: 0,
        }
    }
}

/// Runs `code` as `search.js` with `answerer` answering its fetches.
pub fn run_with_fetch(code: &str, answerer: Answerer, options: RunOptions) -> PluginScriptResult {
    let job = plugin_runtime::begin_job();
    let mut request = request_with(job, vec![file("search.js", code)], "{}", options.timeout_ms);
    request.config = options.config;
    request.storage_json = options.storage_json;
    block_on(plugin_runtime::run_with(request, answerer))
}
