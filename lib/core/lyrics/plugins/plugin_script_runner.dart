import '../../database/library_database.dart';
import '../../database/lyrics_plugin_queries.dart';
import '../../plugin_runtime/plugin_runtime.dart';
import '../online/lyrics_fetch_exception.dart';
import '../online/lyrics_http.dart';
import '../online/lyrics_http_retry.dart' show LyricsRequestAbandoned;
import 'plugin_failure_log.dart';
import 'plugin_fetch_bridge.dart';
import 'plugin_output_reader.dart';
import 'plugin_package_loader.dart';
import 'plugin_run_core.dart';
import 'plugin_run_deadline.dart';
import 'plugin_run_errors.dart';
import 'plugin_run_log.dart';
import 'plugin_run_registry.dart';
import 'store/lyrics_plugin_dirs.dart';

/// Which script of the package to run.
enum PluginScript { search, lyrics }

/// Runs one script of an installed plugin for a lookup and turns what
/// happens into a value or a `LyricsFetchException`. It owns the whole run
/// contract:
///
/// * the run is registered in [PluginRunRegistry] before the record or the
///   package is read, so an uninstall or update cancels it; a plugin that is
///   being changed, missing or removed is skipped (`LyricsSourceSkipped`:
///   no failure, no pause, no "not found" row);
/// * both scripts come from `<root>/<package_dir>/`, read once per folder;
///   an unreadable package is `invalidResponse`, never "not found";
/// * the run has an outer deadline ([pluginRunOuterDeadline]); when it passes
///   the run is cancelled and counts as a `network` failure (like a script
///   timeout);
/// * the storage the script changed is written back only while the record is
///   still the one the run started with;
/// * a failed run, or one that printed to the console, is added to the
///   plugin's log file, and a failure also gets one INFO line in the app log.
///   A cancelled or skipped run writes neither.
class PluginScriptRunner {
  PluginScriptRunner({
    required LibraryDatabase db,
    required PluginRuntime runtime,
    required PluginRunRegistry runs,
    required this._runLog,
    required LyricsPluginDirs dirs,
    required Future<PluginConfigMap> Function(String installId) loadConfig,
    PluginPackageLoader? packages,
    Duration outerDeadline = pluginRunOuterDeadline,
    DateTime Function()? clock,
  }) : _core = PluginRunCore(
         db: db,
         runtime: runtime,
         runs: runs,
         dirs: dirs,
         loadConfig: loadConfig,
         packages: packages,
         outerDeadline: outerDeadline,
       ),
       _clock = clock ?? DateTime.now;

  final PluginRunCore _core;
  final PluginRunLog _runLog;

  /// The run core, so the translate runner shares its package cache.
  PluginRunCore get core => _core;

  final DateTime Function() _clock;

  /// Runs [script] of [installId] with [input] (a JSON-encodable value, also
  /// the `query` of the log line). [http] answers the script's `fetch`
  /// calls; when its lookup is abandoned the next send throws, the run ends
  /// cancelled and this throws `LyricsRequestAbandoned`. [read] turns the
  /// output JSON into the result; it may add notes for the log and throws
  /// [PluginOutputException] for a bad shape.
  Future<T> run<T>({
    required String installId,
    required PluginScript script,
    required Object? input,
    required LyricsHttp http,
    required T Function(String outputJson, List<String> notes) read,
  }) async {
    final outcome = await _core.run(
      installId: installId,
      kind: PluginKind.lyrics,
      entry: (package) => script == PluginScript.search
          ? package.searchScript
          : package.lyricsScript,
      input: input,
      http: (_) => http,
    );
    final row = outcome.row;
    if (row == null) throw const LyricsSourceSkipped();
    final scriptName = script == PluginScript.search
        ? 'search.js'
        : 'lyrics.js';
    PluginRunLogEvent event(
      String kind,
      String message, {
      String? stack,
      List<String> console = const [],
      List<PluginRequestRecord> requests = const [],
    }) => PluginRunLogEvent(
      time: _clock(),
      installId: installId,
      pluginName: row.name,
      version: '${row.version}',
      script: scriptName,
      query: input,
      kind: kind,
      message: message,
      stack: stack,
      console: console,
      requests: requests,
    );

    if (outcome.state == PluginRunState.setupFailed) {
      // A setup timeout is a network failure; anything else is treated like
      // an unreadable input of the plugin.
      final timedOut = outcome.timedOut;
      recordPluginRun(
        _runLog,
        timedOut
            ? event('network', outcome.reason)
            : event('invalidResponse', outcome.reason),
        const {},
        failed: true,
      );
      throw LyricsFetchException(
        timedOut ? LyricsFetchKind.network : LyricsFetchKind.invalidResponse,
      );
    }

    final result = outcome.result!;
    final config = outcome.config;
    final notes = <String>[];
    T? value;
    var outputProblem = '';
    var failure = pluginRunFailure(result);
    if (failure == null) {
      try {
        value = read(result.outputJson, notes);
      } on PluginOutputException catch (e) {
        outputProblem = e.reason;
        failure = const LyricsFetchException(LyricsFetchKind.invalidResponse);
      }
    }
    // Stopped by an update or uninstall, not by the caller (a caller that
    // left arrives as an abandoned fetch): the source is only skipped, so the
    // caller's operation goes on with the other sources.
    if (outcome.stopped) throw const LyricsSourceSkipped();
    if (failure is! LyricsRequestAbandoned && failure is! LyricsSourceSkipped) {
      final ok = failure == null;
      recordPluginRun(
        _runLog,
        event(
          ok ? pluginRunOkKind : pluginFailureName(failure),
          ok
              ? ''
              : (outputProblem.isNotEmpty
                    ? outputProblem
                    : (result.jsError?.message ?? result.errorMessage)),
          stack: result.jsError?.stack,
          console: [...result.logs, for (final n in notes) 'dropped: $n'],
          requests: outcome.requests,
        ),
        config,
        failed: !ok,
      );
    }
    if (failure != null) throw failure;
    return value as T;
  }
}
