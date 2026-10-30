//! Lyrics plugin runtime API exposed to Dart: runs a plugin's JavaScript
//! (`search.js` / `lyrics.js`) in a sandboxed QuickJS engine.
//!
//! A run is three calls. [`begin_plugin_job`] hands out a job id,
//! [`run_plugin_script`] runs the script under that id, and
//! [`cancel_plugin_job`] (from another call) stops it. [`check_plugin_script`]
//! only compiles a script, to report syntax errors at install time.
//!
//! Every struct is flat on purpose so flutter_rust_bridge generates plain
//! Dart classes.

use flutter_rust_bridge::DartFnFuture;

use crate::plugin_runtime;

/// One file of the plugin's `src/` folder, already read and size-checked.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PluginSourceFile {
    /// File name without a folder, e.g. `search.js` or `util.js`.
    pub name: String,
    pub code: String,
}

/// What to run.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PluginScriptRequest {
    /// Id from [`begin_plugin_job`].
    pub job: u32,
    /// All files of the package's `src/` folder; `load()` can only reach these.
    pub files: Vec<PluginSourceFile>,
    /// Name of the file to run first (`search.js` or `lyrics.js`); must be in `files`.
    pub entry: String,
    /// JSON text that becomes the argument of the global `execute(input)`.
    pub input_json: String,
    /// Wall-time limit in milliseconds. 0 or more than 15 000 means 15 000;
    /// a smaller value is only meant for tests. The clock starts when a
    /// worker begins the job: time spent waiting in the queue is not counted,
    /// so the caller should keep its own outer deadline.
    pub timeout_ms: u32,
    /// The plugin's configuration, readable by the script as
    /// `localConfig.getItem(key)`. Secrets included; the runtime never puts
    /// these values in a log line or an error text it makes.
    pub config: Vec<(String, String)>,
    /// The plugin's stored map as a JSON object of strings (`localStorage`).
    /// Empty text means nothing stored.
    pub storage_json: String,
}

/// One `fetch` of the script, handed to the Dart callback.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PluginFetchRequest {
    /// `GET` or `POST`.
    pub method: String,
    /// The script's URL with its `queries` already appended and encoded.
    pub url: String,
    pub headers: Vec<(String, String)>,
    pub body: Vec<u8>,
    /// What is left of the call's 15 s (or the script's smaller `timeout`).
    /// Dart uses the smaller of this and 30 s as the overall timeout.
    pub deadline_ms: u32,
}

/// How Dart answered a [`PluginFetchRequest`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PluginFetchOutcome {
    /// A response arrived; `status`, `url`, `headers` and `body` are set.
    Ok,
    /// Connection, TLS, timeout or similar.
    Network,
    /// The host is not on the plugin's allowlist.
    BlockedHost,
    /// The user has not allowed this plugin to use the network.
    NotConsented,
    /// The user stopped the lookup; the job ends `cancelled`.
    Abandoned,
    /// Dart refused the request (method, header or body).
    InvalidRequest,
    /// Dart refused the answer (e.g. a body over 4 MiB).
    InvalidResponse,
    /// The server asked to slow down; see `retry_after_sec`.
    RateLimited,
}

/// Dart's answer to a [`PluginFetchRequest`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PluginFetchResponse {
    pub outcome: PluginFetchOutcome,
    /// HTTP status; 0 unless `outcome` is `Ok`.
    pub status: u16,
    /// The final URL after redirects.
    pub url: String,
    pub headers: Vec<(String, String)>,
    pub body: Vec<u8>,
    /// For `RateLimited`: the server's `Retry-After` in seconds, if it gave one.
    pub retry_after_sec: Option<u32>,
    /// HTTP sends Dart made for this request, retries counted. The runtime
    /// adds them up and refuses further fetches after 10 in one call.
    pub sends: u32,
}

/// How a run ended.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PluginScriptStatus {
    /// `execute` returned `Response.success`; `output_json` holds its data.
    Ok,
    /// The script threw, failed to compile, broke the contract (no `execute`,
    /// not a `Response`, bad `load()`), or returned `Response.error`. See
    /// `error_kind`, `error_message` and `js_error`.
    ScriptError,
    /// The 15 s wall-time limit passed.
    Timeout,
    /// The 32 MiB heap limit was hit.
    Memory,
    /// The script stack limit (1 MiB) was hit.
    Stack,
    /// The job was cancelled (or its id was unknown or already cancelled).
    Cancelled,
    /// The returned data is larger than 2 MiB as JSON.
    OutputTooLarge,
    /// The runtime failed (a worker panicked, the request was malformed).
    /// Not the script's fault.
    Internal,
    /// All workers were busy and the queue was full. Nothing ran; skip the
    /// source for this lookup, record no failure and start no pause.
    Busy,
}

/// Kind of a script-reported failure.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PluginErrorKind {
    /// Not a script-reported failure.
    None,
    /// The source asked to slow down; see `retry_after_sec`.
    RateLimited,
    /// The script returned something that is not a `Response`.
    InvalidResponse,
    /// Any other failure (default for `Response.error` and for exceptions).
    Server,
}

/// A JavaScript exception: its message and stack (file names and line numbers kept).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PluginJsError {
    pub message: String,
    /// Empty when the engine gave no stack.
    pub stack: String,
}

/// Why the first failing host `fetch` of a call failed (same names as
/// [`PluginFetchOutcome`]). A call that used up its 10 sends reports
/// `InvalidRequest`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PluginFetchFailureKind {
    Network,
    BlockedHost,
    NotConsented,
    Abandoned,
    InvalidRequest,
    InvalidResponse,
    RateLimited,
}

/// The first failing `fetch` of a call, kept even when the script caught the error.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PluginFetchFailure {
    pub kind: PluginFetchFailureKind,
    pub retry_after_sec: Option<u32>,
    /// Runtime-made text; never contains configuration values.
    pub message: String,
}

/// Result of one run. Every field is filled on every status: `logs`,
/// `js_error` and `fetch_failure` are returned even when the run failed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PluginScriptResult {
    pub status: PluginScriptStatus,
    /// JSON of the `data` given to `Response.success`. Empty unless `status` is `Ok`.
    pub output_json: String,
    /// Human text for every status except `Ok`: the `Response.error` message,
    /// the exception message, or what the runtime enforced.
    pub error_message: String,
    /// Set for `Response.error`, `InvalidResponse` and thrown exceptions.
    pub error_kind: PluginErrorKind,
    /// From `Response.error(message, {retryAfterSec})`.
    pub retry_after_sec: Option<u32>,
    /// The JavaScript exception that ended the run, when the engine had one:
    /// thrown errors, syntax errors, limit errors and interrupts. `None` when
    /// no script code was running (cancelled before start, busy, internal) or
    /// the failure was found by the host after `execute` returned (not a
    /// `Response`, output too large, `Response.error`).
    pub js_error: Option<PluginJsError>,
    /// Console lines captured before the run ended, whatever the status.
    pub logs: Vec<String>,
    /// First failing host `fetch`, whatever the status.
    pub fetch_failure: Option<PluginFetchFailure>,
    /// The plugin's whole new storage map as JSON, only when the script
    /// changed it. Concurrent calls of one plugin: the last writer wins.
    pub storage_json: Option<String>,
}

/// A syntax error found by [`check_plugin_script`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PluginScriptProblem {
    pub message: String,
    /// 1-based line; 0 when unknown.
    pub line: u32,
}

/// Starts a job and returns its id. Ids come from the native side and only
/// rise, so they stay unique across hot restarts of the Dart side.
///
/// Pass every begun id to [`run_plugin_script`], even a cancelled one: the
/// registry entry is freed there. (A job cancelled before it ran frees its
/// entry at once.)
#[flutter_rust_bridge::frb(sync)]
pub fn begin_plugin_job() -> u32 {
    plugin_runtime::begin_job()
}

/// Stops job `job`: [`run_plugin_script`] returns [`PluginScriptStatus::Cancelled`]
/// within about 100 ms. A job that has not been run yet is forgotten, so a
/// later run with that id is `Cancelled` at once. An unknown or finished id
/// does nothing.
#[flutter_rust_bridge::frb(sync)]
pub fn cancel_plugin_job(job: u32) {
    plugin_runtime::cancel_job(job);
}

/// Runs the plugin script on one of 4 JS threads. Only queues the job and
/// awaits the result, so no bridge worker blocks. Never panics; a full queue
/// (16 waiting) is [`PluginScriptStatus::Busy`].
///
/// `fetch` is the Dart callback that answers the script's `fetch` calls. It is
/// called on the JS thread, which then waits for the returned future (until
/// the job is cancelled or its deadline passes); the Dart isolate stays free.
pub async fn run_plugin_script(
    request: PluginScriptRequest,
    fetch: impl Fn(PluginFetchRequest) -> DartFnFuture<PluginFetchResponse> + Send + Sync + 'static,
) -> PluginScriptResult {
    plugin_runtime::run_with(request, std::sync::Arc::new(fetch)).await
}

/// Compiles `code` as a classic script named `name` without running it.
/// `None` when it parses, else the first syntax problem.
pub fn check_plugin_script(name: String, code: String) -> Option<PluginScriptProblem> {
    plugin_runtime::check_script(&name, &code)
}
