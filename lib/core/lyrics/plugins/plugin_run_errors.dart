import '../../plugin_runtime/plugin_runtime.dart';
import '../online/lyrics_fetch_exception.dart';
import '../online/lyrics_http_retry.dart' show LyricsRequestAbandoned;

/// What a finished run means for the lookup: `null` when it ended well, else
/// the exception to throw. The order decides:
///
/// 1. cancelled: [LyricsRequestAbandoned];
/// 2. a failed `fetch` of the run (even one the script caught, even when it
///    then returned data), by its kind, so a swallowed error is never stored
///    as "no lyrics". `invalidRequest` is the plugin's fault and becomes
///    `invalidResponse`;
/// 3. an error response of the script: its kind (`server` by default) with
///    its `retryAfterSec`;
/// 4. busy: [LyricsSourceSkipped] (every worker was busy; not a failure);
///    timeout: `network`; memory, stack, a script error without a kind, an
///    output over the limit, and an internal failure of the runtime:
///    `invalidResponse`. An internal failure is the host's fault, not the
///    plugin's, but it is mapped like the others: the source is paused for a
///    while instead of being asked again at once.
///
/// A run that ended `ok` with no failed `fetch` returns `null`; reading its
/// data (and a bad shape, which is `invalidResponse`) is up to the caller.
Exception? pluginRunFailure(PluginRunResult result) {
  if (result.status == PluginRunStatus.cancelled) {
    return const LyricsRequestAbandoned();
  }
  final fetch = result.fetchFailure;
  if (fetch != null) return _fromFetchFailure(fetch);
  return switch (result.status) {
    PluginRunStatus.ok => null,
    PluginRunStatus.cancelled => const LyricsRequestAbandoned(),
    PluginRunStatus.busy => const LyricsSourceSkipped(),
    PluginRunStatus.timeout => const LyricsFetchException(
      LyricsFetchKind.network,
    ),
    PluginRunStatus.scriptError => _fromScriptError(result),
    PluginRunStatus.memory ||
    PluginRunStatus.stack ||
    PluginRunStatus.outputTooLarge ||
    PluginRunStatus.internal => const LyricsFetchException(
      LyricsFetchKind.invalidResponse,
    ),
  };
}

/// Throws what [pluginRunFailure] returns, if anything.
void throwPluginRunFailure(PluginRunResult result) {
  final failure = pluginRunFailure(result);
  if (failure != null) throw failure;
}

/// The short name of a failure for the plugin log and the app log:
/// `abandoned`, `skipped` or the name of the `LyricsFetchKind`.
String pluginFailureName(Object failure) => switch (failure) {
  LyricsFetchException(:final kind) => kind.name,
  LyricsRequestAbandoned() => 'abandoned',
  LyricsSourceSkipped() => 'skipped',
  _ => 'invalidResponse',
};

Exception _fromFetchFailure(PluginFetchFailure failure) =>
    switch (failure.kind) {
      PluginFetchFailureKind.abandoned => const LyricsRequestAbandoned(),
      PluginFetchFailureKind.network => const LyricsFetchException(
        LyricsFetchKind.network,
      ),
      PluginFetchFailureKind.blockedHost => const LyricsFetchException(
        LyricsFetchKind.blockedHost,
      ),
      PluginFetchFailureKind.notConsented => const LyricsFetchException(
        LyricsFetchKind.notConsented,
      ),
      PluginFetchFailureKind.invalidRequest ||
      PluginFetchFailureKind.invalidResponse => const LyricsFetchException(
        LyricsFetchKind.invalidResponse,
      ),
      PluginFetchFailureKind.rateLimited => _rateLimited(failure.retryAfterSec),
    };

Exception _fromScriptError(PluginRunResult result) =>
    switch (result.errorKind) {
      PluginRunErrorKind.rateLimited => _rateLimited(result.retryAfterSec),
      PluginRunErrorKind.invalidResponse || PluginRunErrorKind.none =>
        const LyricsFetchException(LyricsFetchKind.invalidResponse),
      PluginRunErrorKind.server => const LyricsFetchException(
        LyricsFetchKind.server,
      ),
    };

// The wait is read like a `Retry-After` header: whole seconds, clamped to
// 1 s..15 min.
LyricsFetchException _rateLimited(int? seconds) => LyricsFetchException(
  LyricsFetchKind.rateLimited,
  retryAfter: seconds == null ? null : parseRetryAfter('$seconds'),
);
