//! Runs one plugin job on the calling thread: a fresh `Runtime` and `Context`
//! with the limits, the script, the call of `execute`, and the mapping of
//! every way it can end to a [`PluginScriptResult`].
//!
//! `Runtime` and `Context` are `!Send`, are created and dropped here, and
//! never outlive the call. The caller must give the thread a large stack
//! ([`super::limits::THREAD_STACK_BYTES`]).

use std::collections::HashMap;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::atomic::{AtomicBool, AtomicU8, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use rquickjs::{Context, Ctx, Runtime};

use super::collector::Collector;
use super::globals::{self, Finished, JsFailure, RunFailure, Sources};
use super::host::{HostEnv, STOP_CANCELLED, STOP_INTERNAL, STOP_NONE, STOP_TIMEOUT};
use super::host_budget::ByteBudget;
use super::host_callback::{no_network, Answerer};
use super::limits::{MAX_OUTPUT_BYTES, MEMORY_LIMIT_BYTES, RUST_BYTE_BUDGET, SCRIPT_STACK_BYTES};
use super::memory::LimitedAllocator;
use crate::api::plugin_runtime::{
    PluginErrorKind, PluginJsError, PluginScriptResult, PluginScriptStatus,
};

/// Everything one run needs.
pub struct JobSpec {
    /// Id of the job in the registry (0 when the spec was not made for a request).
    pub job: u32,
    pub sources: Sources,
    pub entry: String,
    pub input_json: String,
    pub timeout: Duration,
    pub cancel: Arc<AtomicBool>,
    /// Read-only `localConfig` entries.
    pub config: Vec<(String, String)>,
    /// The plugin's stored map as JSON; empty means nothing stored.
    pub storage_json: String,
    /// Answers `fetch` calls; the default has no network.
    pub answerer: Answerer,
}

impl JobSpec {
    /// Builds a spec from owned files; `None` when a file name repeats.
    pub fn new(
        files: impl IntoIterator<Item = (String, String)>,
        entry: String,
        input_json: String,
        timeout: Duration,
        cancel: Arc<AtomicBool>,
    ) -> Option<Self> {
        let mut map = HashMap::new();
        for (name, code) in files {
            if map.insert(name, code).is_some() {
                return None;
            }
        }
        Some(Self {
            job: 0,
            sources: Arc::new(map),
            entry,
            input_json,
            timeout,
            cancel,
            config: Vec::new(),
            storage_json: String::new(),
            answerer: no_network(),
        })
    }
}

/// A result with no script output; `logs`, `fetch_failure` and `storage_json`
/// are added from the collector by [`run_job`].
pub fn failure(status: PluginScriptStatus, message: impl Into<String>) -> PluginScriptResult {
    PluginScriptResult {
        status,
        output_json: String::new(),
        error_message: message.into(),
        error_kind: PluginErrorKind::None,
        retry_after_sec: None,
        js_error: None,
        logs: Vec::new(),
        fetch_failure: None,
        storage_json: None,
    }
}

/// Runs the job and always returns a result: a panic inside is `Internal`.
/// Console lines and other captured data survive every failure path because
/// they live in a collector made before the guarded part.
pub fn run_job(spec: &JobSpec) -> PluginScriptResult {
    let collector = Collector::new();
    let mut result = catch_unwind(AssertUnwindSafe(|| run_guarded(spec, &collector)))
        .unwrap_or_else(|_| failure(PluginScriptStatus::Internal, "the plugin worker panicked"));
    collector.fill(&mut result);
    result
}

fn run_guarded(spec: &JobSpec, collector: &Collector) -> PluginScriptResult {
    if spec.cancel.load(Ordering::SeqCst) {
        return failure(PluginScriptStatus::Cancelled, "cancelled before start");
    }
    if !spec.sources.contains_key(&spec.entry) {
        return failure(
            PluginScriptStatus::Internal,
            format!("entry file {} is not in the request files", spec.entry),
        );
    }
    let deadline = Instant::now() + spec.timeout;
    let stop = Arc::new(AtomicU8::new(STOP_NONE));

    let (allocator, memory_hit) = LimitedAllocator::new(MEMORY_LIMIT_BYTES);
    let runtime = match Runtime::new_with_alloc(allocator) {
        Ok(rt) => rt,
        Err(e) => return failure(PluginScriptStatus::Internal, format!("runtime: {e}")),
    };
    runtime.set_max_stack_size(SCRIPT_STACK_BYTES);
    {
        let (stop, cancel) = (stop.clone(), spec.cancel.clone());
        runtime.set_interrupt_handler(Some(Box::new(move || {
            if cancel.load(Ordering::SeqCst) {
                let _ = stop.compare_exchange(
                    STOP_NONE,
                    STOP_CANCELLED,
                    Ordering::SeqCst,
                    Ordering::SeqCst,
                );
                true
            } else if Instant::now() >= deadline {
                let _ = stop.compare_exchange(
                    STOP_NONE,
                    STOP_TIMEOUT,
                    Ordering::SeqCst,
                    Ordering::SeqCst,
                );
                true
            } else {
                false
            }
        })));
    }
    let context = match Context::full(&runtime) {
        Ok(c) => c,
        Err(e) => return failure(PluginScriptStatus::Internal, format!("context: {e}")),
    };

    let budget_hit = Arc::new(AtomicBool::new(false));
    let host = HostEnv {
        deadline,
        cancel: spec.cancel.clone(),
        stop: stop.clone(),
        budget: ByteBudget::new(RUST_BYTE_BUDGET, budget_hit.clone()),
        collector: collector.clone(),
        answerer: spec.answerer.clone(),
        config: spec.config.iter().cloned().collect(),
        storage_json: spec.storage_json.clone(),
    };
    let result =
        context.with(|ctx| run_in_context(&ctx, spec, host, &stop, &memory_hit, &budget_hit));
    // Drop order matters: Context first, Runtime last, both on this thread.
    drop(context);
    drop(runtime);
    result
}

fn run_in_context<'js>(
    ctx: &Ctx<'js>,
    spec: &JobSpec,
    host: HostEnv,
    stop: &AtomicU8,
    memory_hit: &AtomicBool,
    budget_hit: &AtomicBool,
) -> PluginScriptResult {
    // A cancel or the deadline can land while the globals are being set up;
    // that is still a cancel or a timeout, not an internal failure.
    let setup_failed = |f: JsFailure, what: &str| {
        let stopped = stop.load(Ordering::SeqCst);
        if stopped != STOP_NONE {
            return map_js_failure(f, stopped, memory_hit.load(Ordering::SeqCst), spec.timeout);
        }
        failure(
            PluginScriptStatus::Internal,
            format!("{what}: {}", f.message),
        )
    };
    let helpers = match globals::install(ctx, spec.sources.clone(), &spec.entry, host) {
        Ok(h) => h,
        Err(e) => return setup_failed(globals::describe_error(ctx, e), "globals"),
    };
    let input = match ctx.json_parse(spec.input_json.as_str()) {
        Ok(v) => v,
        Err(e) => {
            return setup_failed(
                globals::describe_error(ctx, e),
                "input_json is not valid JSON",
            )
        }
    };

    let entry_code = &spec.sources[&spec.entry];
    let outcome = match globals::eval_classic(ctx, entry_code, &spec.entry) {
        Ok(_) => globals::call_execute(ctx, input, &helpers),
        Err(e) => Err(RunFailure::Js(globals::describe_error(ctx, e))),
    };
    let result = match outcome {
        Ok(Finished::Success { output_json }) => PluginScriptResult {
            output_json,
            ..failure(PluginScriptStatus::Ok, "")
        },
        Ok(Finished::ScriptError {
            message,
            kind,
            retry_after_sec,
        }) => PluginScriptResult {
            error_kind: kind,
            retry_after_sec,
            ..failure(PluginScriptStatus::ScriptError, message)
        },
        Err(RunFailure::Js(f)) => map_js_failure(
            f,
            stop.load(Ordering::SeqCst),
            memory_hit.load(Ordering::SeqCst),
            spec.timeout,
        ),
        Err(RunFailure::Contract(message)) => PluginScriptResult {
            error_kind: PluginErrorKind::Server,
            ..failure(PluginScriptStatus::ScriptError, message)
        },
        Err(RunFailure::InvalidResponse(message)) => PluginScriptResult {
            error_kind: PluginErrorKind::InvalidResponse,
            ..failure(PluginScriptStatus::ScriptError, message)
        },
        Err(RunFailure::OutputTooLarge) => failure(
            PluginScriptStatus::OutputTooLarge,
            format!("the output is larger than the limit of {MAX_OUTPUT_BYTES} bytes of JSON"),
        ),
    };
    // A blocked host call (fetch, sleep) that saw the cancel or the deadline
    // throws a catchable error. If the script swallowed it and went on, the
    // call still ends as cancelled / timed out, never as a normal result.
    let stopped = stop.load(Ordering::SeqCst);
    if stopped != STOP_NONE && result.js_error.is_none() {
        let (status, message) = stop_status(stopped, spec.timeout);
        return failure(status, message);
    }
    // The Rust byte budget was overrun, or the QuickJS heap cap refused an
    // allocation, at some point: the call is `memory` even if the script
    // caught the error and returned normally.
    if (budget_hit.load(Ordering::SeqCst) || memory_hit.load(Ordering::SeqCst))
        && !matches!(
            result.status,
            PluginScriptStatus::Cancelled | PluginScriptStatus::Timeout
        )
    {
        return PluginScriptResult {
            js_error: result.js_error,
            ..failure(PluginScriptStatus::Memory, memory_message())
        };
    }
    result
}

fn memory_message() -> String {
    format!(
        "the script used more than {} MiB of memory",
        MEMORY_LIMIT_BYTES >> 20
    )
}

/// Text of a run stopped because a host function panicked.
const INTERNAL_MESSAGE: &str = "a host function failed internally";

/// Status and text of a run stopped by cancel, deadline or an internal failure.
fn stop_status(stop: u8, timeout: Duration) -> (PluginScriptStatus, String) {
    if stop == STOP_CANCELLED {
        (PluginScriptStatus::Cancelled, "cancelled".to_owned())
    } else if stop == STOP_INTERNAL {
        (PluginScriptStatus::Internal, INTERNAL_MESSAGE.to_owned())
    } else {
        (
            PluginScriptStatus::Timeout,
            format!("the script ran longer than {} ms", timeout.as_millis()),
        )
    }
}

/// The engine's own stack-limit exception: a `RangeError` or `InternalError`
/// with its exact message. (A script can still throw one by hand; that only
/// changes its own status.)
fn is_engine_stack_overflow(f: &JsFailure) -> bool {
    matches!(f.name.as_str(), "RangeError" | "InternalError")
        && matches!(
            f.message.as_str(),
            "Maximum call stack size exceeded" | "stack overflow"
        )
}

/// Status of a run the engine ended with an exception. The interrupt reason
/// and the allocator's memory flag come first (a script cannot fake them: an
/// out-of-memory error may even reach the script as a bare `null`); then the
/// engine's own stack message.
fn map_js_failure(
    f: JsFailure,
    stop: u8,
    memory_hit: bool,
    timeout: Duration,
) -> PluginScriptResult {
    let (status, error_kind, message) = match stop {
        STOP_CANCELLED => (
            PluginScriptStatus::Cancelled,
            PluginErrorKind::None,
            "cancelled".to_owned(),
        ),
        STOP_TIMEOUT => (
            PluginScriptStatus::Timeout,
            PluginErrorKind::None,
            format!("the script ran longer than {} ms", timeout.as_millis()),
        ),
        STOP_INTERNAL => (
            PluginScriptStatus::Internal,
            PluginErrorKind::None,
            INTERNAL_MESSAGE.to_owned(),
        ),
        _ if memory_hit => (
            PluginScriptStatus::Memory,
            PluginErrorKind::None,
            format!(
                "the script used more than {} MiB of memory",
                MEMORY_LIMIT_BYTES >> 20
            ),
        ),
        _ if is_engine_stack_overflow(&f) => (
            PluginScriptStatus::Stack,
            PluginErrorKind::None,
            "the script nested calls too deeply".to_owned(),
        ),
        _ => (
            PluginScriptStatus::ScriptError,
            PluginErrorKind::Server,
            f.message.clone(),
        ),
    };
    PluginScriptResult {
        error_kind,
        js_error: Some(PluginJsError {
            message: f.message,
            stack: f.stack,
        }),
        ..failure(status, message)
    }
}
