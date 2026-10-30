//! Lyrics plugin runtime: sandboxed JavaScript (QuickJS-NG) for search and
//! lyrics plugins. The bridge surface is `crate::api::plugin_runtime`; this
//! module is the facade it calls.
//!
//! Model: a pool of [`limits::WORKER_THREADS`] threads; every job builds a
//! fresh `Runtime` + `Context` on its worker, runs, and drops both there.
//! See `docs/lyrics-plugin-api.md` ("Runtime and limits").

mod charset;
mod collector;
mod compile_check;
// `engine` and `limits` are public only so the integration tests under
// `rust/tests` can reach them; they are not an API.
#[doc(hidden)]
pub mod engine;
mod globals;
mod host;
mod host_budget;
mod host_callback;
mod host_console;
mod host_fetch;
mod host_html;
mod host_html_select;
mod host_html_serialize;
mod host_html_sink;
mod host_html_text;
mod host_sleep;
mod host_storage;
mod jobs;
#[doc(hidden)]
pub mod limits;
mod memory;
mod pool;

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, OnceLock};

use crate::api::plugin_runtime::{
    PluginScriptProblem, PluginScriptRequest, PluginScriptResult, PluginScriptStatus,
};
use engine::{failure, JobSpec};
// Re-exported so tests and the bridge can name the answerer type and make one.
pub use host_callback::{failed_response, no_network, Answerer};
use pool::{completion, Completer, Pool};

/// A job waiting for or running on a worker.
struct QueuedJob {
    spec: JobSpec,
    done: Completer<PluginScriptResult>,
}

fn pool() -> Option<&'static Arc<Pool<QueuedJob>>> {
    static POOL: OnceLock<Option<Arc<Pool<QueuedJob>>>> = OnceLock::new();
    POOL.get_or_init(|| {
        Pool::start(
            limits::WORKER_THREADS,
            limits::QUEUE_CAPACITY,
            "plugin-js",
            limits::THREAD_STACK_BYTES,
            |job: QueuedJob| {
                let result = engine::run_job(&job.spec);
                job.done.send(result);
            },
        )
        .ok()
    })
    .as_ref()
}

pub fn begin_job() -> u32 {
    jobs::registry().begin()
}

/// Cancels job `id`. A job still waiting in the queue ends `Cancelled` at
/// once and gives its slot back; a running one stops at the next interrupt.
pub fn cancel_job(id: u32) {
    jobs::registry().cancel(id);
    if let Some(pool) = pool() {
        complete_cancelled(pool.take_where(|queued| queued.spec.job == id));
    }
}

/// Finishes jobs taken out of the queue because they were cancelled.
fn complete_cancelled(jobs: Vec<QueuedJob>) {
    for job in jobs {
        job.done.send(failure(
            PluginScriptStatus::Cancelled,
            "cancelled before start",
        ));
    }
}

/// Sets the cancel flag when dropped: if the future of a Rust caller is
/// dropped, the worker stops instead of running to the deadline. (The Dart
/// bridge never drops the future; Dart stops a job with `cancel_plugin_job`.)
struct StopOnDrop(Arc<AtomicBool>);

impl Drop for StopOnDrop {
    fn drop(&mut self) {
        self.0.store(true, Ordering::SeqCst);
    }
}

/// [`run_with`] for a run that has no network: every `fetch` fails with `network`.
pub async fn run(request: PluginScriptRequest) -> PluginScriptResult {
    run_with(request, host_callback::no_network()).await
}

/// Queues the request and awaits its result. `fetch` calls of the script go to
/// `answerer` on the JS worker thread. Never panics.
pub async fn run_with(request: PluginScriptRequest, answerer: Answerer) -> PluginScriptResult {
    let Some(guard) = jobs::registry().claim(request.job) else {
        return failure(PluginScriptStatus::Cancelled, "unknown or cancelled job id");
    };
    let cancel = guard.cancel_flag();
    let files = request.files.into_iter().map(|f| (f.name, f.code));
    let Some(spec) = JobSpec::new(
        files,
        request.entry,
        request.input_json,
        limits::effective_wall_time(request.timeout_ms),
        cancel.clone(),
    ) else {
        return failure(PluginScriptStatus::Internal, "two files share a name");
    };
    let spec = JobSpec {
        job: request.job,
        config: request.config,
        storage_json: request.storage_json,
        answerer,
        ..spec
    };
    let Some(pool) = pool() else {
        return failure(
            PluginScriptStatus::Internal,
            "no JS worker thread could start",
        );
    };
    let (done, waiter) = completion();
    // Jobs cancelled while waiting must not hold queue slots.
    complete_cancelled(pool.take_where(|queued| queued.spec.cancel.load(Ordering::SeqCst)));
    if pool.try_submit(QueuedJob { spec, done }).is_err() {
        return failure(
            PluginScriptStatus::Busy,
            "all JS workers are busy and the queue is full",
        );
    }
    let _stop = StopOnDrop(cancel);
    // `guard` lives to here: the id is spent when the job ends.
    let result = waiter
        .await
        .unwrap_or_else(|| failure(PluginScriptStatus::Internal, "the JS worker was lost"));
    drop(guard);
    result
}

/// Compile-only syntax check; see [`compile_check::check_script`].
pub fn check_script(name: &str, code: &str) -> Option<PluginScriptProblem> {
    compile_check::check_script(name, code)
}

#[cfg(test)]
mod tests;
