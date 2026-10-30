/// How a plugin run ended.
enum PluginRunStatus {
  /// `execute` returned a success; [PluginRunResult.outputJson] holds its data.
  ok,

  /// The script threw, failed to compile, broke the contract, or returned an
  /// error response.
  scriptError,

  /// The wall-time limit passed.
  timeout,

  /// The heap limit was hit.
  memory,

  /// The script stack limit was hit.
  stack,

  /// The run was cancelled.
  cancelled,

  /// The returned data is larger than the output limit.
  outputTooLarge,

  /// The runtime failed. Not the script's fault.
  internal,

  /// All workers were busy and the queue was full. Nothing ran; skip the
  /// source for this lookup.
  busy,
}

/// Kind of a script-reported failure.
enum PluginRunErrorKind {
  /// Not a script-reported failure.
  none,
  rateLimited,
  invalidResponse,

  /// Any other failure.
  server,
}

/// A JavaScript exception that ended the run.
class PluginJsError {
  const PluginJsError({required this.message, this.stack});

  final String message;

  /// File names and line numbers; null when the engine gave no stack.
  final String? stack;
}

/// Why the first failing host `fetch` of a run failed.
enum PluginFetchFailureKind {
  network,
  blockedHost,
  notConsented,
  abandoned,
  invalidRequest,
  invalidResponse,
  rateLimited,
}

/// The first failing `fetch` of a run, kept even when the script caught it.
class PluginFetchFailure {
  const PluginFetchFailure({
    required this.kind,
    this.retryAfterSec,
    required this.message,
  });

  final PluginFetchFailureKind kind;
  final int? retryAfterSec;

  /// Runtime-made text; never contains configuration values.
  final String message;
}

/// Result of one run. [logs], [jsError] and [fetchFailure] are filled on every
/// status, failed runs included.
class PluginRunResult {
  const PluginRunResult({
    required this.status,
    this.outputJson = '',
    this.errorMessage = '',
    this.errorKind = PluginRunErrorKind.none,
    this.retryAfterSec,
    this.jsError,
    this.logs = const [],
    this.fetchFailure,
    this.storage,
  });

  final PluginRunStatus status;

  /// JSON of the success data; empty unless [status] is [PluginRunStatus.ok].
  final String outputJson;

  /// Human text for every status except ok.
  final String errorMessage;
  final PluginRunErrorKind errorKind;

  /// From an error response of the script.
  final int? retryAfterSec;

  /// The exception that ended the run, when the engine had one.
  final PluginJsError? jsError;

  /// Console lines captured before the run ended.
  final List<String> logs;
  final PluginFetchFailure? fetchFailure;

  /// The plugin's whole new storage map as JSON. Set only when the script
  /// changed it and finished on its own (ok or scriptError); null otherwise.
  final String? storage;
}
