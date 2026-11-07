import '../database/library_database.dart';
import '../lyrics/online/lyrics_fetch_exception.dart';
import '../lyrics/plugins/plugin_failure_log.dart';
import '../lyrics/plugins/plugin_fetch_bridge.dart';
import '../lyrics/plugins/plugin_run_core.dart';
import '../lyrics/plugins/plugin_run_log.dart';
import '../lyrics/plugins/store/plugin_config_schema_codec.dart';
import '../plugin_runtime/plugin_runtime.dart';
import 'source_models.dart';

/// What a finished source run means: `null` when it ended `ok` (the output is
/// checked by the caller), else the kind of failure. The order:
///
/// 1. cancelled, or a `fetch` the caller abandoned: `skipped`;
/// 2. a `fetch` refused for want of consent: `notConsented`, even when the
///    script caught it;
/// 3. ok: `null`. Another `fetch` the script caught is ignored, so a script
///    that fell back to another address still succeeds;
/// 4. busy: `busy`; timeout: `network`; output over the limit:
///    `invalidOutput`; memory or stack: `unavailable`; a runtime failure:
///    `internal`;
/// 5. a script error by its kind: `auth`; `rateLimited` and `quota` are
///    `rateLimited`; `invalidResponse` is `unavailable`; `server` and no kind
///    defer to the first failed `fetch` when there was one (a network error
///    is `network`, a busy answer `rateLimited`, anything else
///    `unavailable`), else `unavailable`.
SourceFailureKind? sourceFailureKind(PluginRunResult result) {
  if (result.status == PluginRunStatus.cancelled) {
    return SourceFailureKind.skipped;
  }
  switch (result.fetchFailure?.kind) {
    case PluginFetchFailureKind.abandoned:
      return SourceFailureKind.skipped;
    case PluginFetchFailureKind.notConsented:
      return SourceFailureKind.notConsented;
    default:
  }
  return switch (result.status) {
    PluginRunStatus.ok => null,
    PluginRunStatus.cancelled => SourceFailureKind.skipped,
    PluginRunStatus.busy => SourceFailureKind.busy,
    PluginRunStatus.timeout => SourceFailureKind.network,
    PluginRunStatus.outputTooLarge => SourceFailureKind.invalidOutput,
    PluginRunStatus.memory ||
    PluginRunStatus.stack => SourceFailureKind.unavailable,
    PluginRunStatus.internal => SourceFailureKind.internal,
    PluginRunStatus.scriptError => _fromScriptError(result),
  };
}

SourceFailureKind _fromScriptError(PluginRunResult result) {
  switch (result.errorKind) {
    case PluginRunErrorKind.auth:
      return SourceFailureKind.auth;
    case PluginRunErrorKind.rateLimited:
    case PluginRunErrorKind.quota:
      return SourceFailureKind.rateLimited;
    case PluginRunErrorKind.invalidResponse:
      return SourceFailureKind.unavailable;
    case PluginRunErrorKind.server:
    case PluginRunErrorKind.none:
      return switch (result.fetchFailure?.kind) {
        PluginFetchFailureKind.network => SourceFailureKind.network,
        PluginFetchFailureKind.rateLimited => SourceFailureKind.rateLimited,
        PluginFetchFailureKind.notConsented => SourceFailureKind.notConsented,
        PluginFetchFailureKind.abandoned => SourceFailureKind.skipped,
        PluginFetchFailureKind.blockedHost ||
        PluginFetchFailureKind.invalidRequest ||
        PluginFetchFailureKind.invalidResponse ||
        null => SourceFailureKind.unavailable,
      };
  }
}

/// The text the script passed to `Response.error`; empty for any other end.
String sourceFailureMessage(PluginRunResult result) =>
    result.status == PluginRunStatus.scriptError &&
        result.errorKind != PluginRunErrorKind.none
    ? result.errorMessage
    : '';

/// Whether a run that ended with [kind] goes to the plugin's log: not when
/// nothing is the plugin's doing (skipped, busy, no consent).
bool sourceRunIsLogged(SourceFailureKind? kind) =>
    kind != SourceFailureKind.skipped &&
    kind != SourceFailureKind.busy &&
    kind != SourceFailureKind.notConsented;

/// Writes one source run to the plugin's log file (when it failed or printed
/// to the console) and, for a failure, one INFO line to the app log. [query]
/// is the script input (the search text included: the file stays on this
/// device). [blockedHost] writes the failure as `blockedHost`, so the app
/// log names the host; [recordFinishedSourceRun] sets it only when the
/// failure came from that blocked `fetch`.
void recordSourceRun(
  PluginRunLog log, {
  required LyricsPluginRow row,
  required String script,
  required Object? query,
  required DateTime time,
  required SourceFailureKind? failure,
  PluginConfigMap config = const {},
  String message = '',
  String? stack,
  List<String> console = const [],
  List<PluginRequestRecord> requests = const [],
  bool blockedHost = false,
}) => recordPluginRun(
  log,
  PluginRunLogEvent(
    time: time,
    installId: row.installId,
    pluginName: row.name,
    version: '${row.version}',
    script: script,
    query: query,
    kind: failure == null
        ? pluginRunOkKind
        : (blockedHost ? LyricsFetchKind.blockedHost.name : failure.name),
    message: failure == null ? '' : message,
    stack: stack,
    console: console,
    requests: requests,
  ),
  config,
  schema: decodePluginConfigSchema(row.configSchema),
  failed: failure != null,
  appLogLabel: 'Source plugin',
);

/// Writes the finished run [outcome] with [recordSourceRun]: its console
/// lines, requests and error, [problem] (what was wrong with the output)
/// before the script's own text, and one `dropped:` line per note.
void recordFinishedSourceRun(
  PluginRunLog log,
  PluginRunOutcome outcome, {
  required String script,
  required Object? query,
  required DateTime time,
  required SourceFailureKind? failure,
  String problem = '',
  List<String> notes = const [],
}) {
  final result = outcome.result!;
  recordSourceRun(
    log,
    row: outcome.row!,
    script: script,
    query: query,
    time: time,
    failure: failure,
    config: outcome.config,
    message: problem.isNotEmpty
        ? problem
        : (result.jsError?.message ?? result.errorMessage),
    stack: result.jsError?.stack,
    console: [...result.logs, for (final n in notes) 'dropped: $n'],
    requests: outcome.requests,
    blockedHost: _failedOnBlockedHost(result, failure),
  );
}

/// Whether [failure] is the `unavailable` a blocked `fetch` gave: a script
/// error without a kind of its own (or `server`) after a refused host. A
/// failure of another kind (the script's `auth`, bad output) keeps its name.
bool _failedOnBlockedHost(PluginRunResult result, SourceFailureKind? failure) =>
    failure == SourceFailureKind.unavailable &&
    result.status == PluginRunStatus.scriptError &&
    (result.errorKind == PluginRunErrorKind.server ||
        result.errorKind == PluginRunErrorKind.none) &&
    result.fetchFailure?.kind == PluginFetchFailureKind.blockedHost;
