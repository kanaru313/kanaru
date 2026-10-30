import 'dart:async';
import 'dart:convert';

import '../../database/library_database.dart';
import '../../database/lyrics_plugin_queries.dart';
import '../../plugin_runtime/plugin_runtime.dart';
import '../online/lyrics_fetch_exception.dart';
import '../online/lyrics_http.dart';
import '../online/lyrics_http_retry.dart' show LyricsRequestAbandoned;
import 'plugin_fetch_bridge.dart';
import 'plugin_output_reader.dart';
import 'plugin_package_loader.dart';
import 'plugin_run_deadline.dart';
import 'plugin_run_errors.dart';
import 'plugin_run_setup.dart';
import 'plugin_storage_writeback.dart';
import 'plugin_failure_log.dart';
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
    required this._db,
    required this._runtime,
    required this._runs,
    required this._runLog,
    required this._dirs,
    required this._loadConfig,
    PluginPackageLoader? packages,
    this._outerDeadline = pluginRunOuterDeadline,
    DateTime Function()? clock,
  }) : _packages = packages ?? PluginPackageLoader(),
       _clock = clock ?? DateTime.now;

  final LibraryDatabase _db;
  final PluginRuntime _runtime;
  final PluginRunRegistry _runs;
  final PluginRunLog _runLog;
  final LyricsPluginDirs _dirs;
  final Future<Map<String, String>> Function(String installId) _loadConfig;
  final PluginPackageLoader _packages;
  final Duration _outerDeadline;
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
    final cancel = PluginCancel();
    final unregister = _runs.register(installId, cancel);
    if (unregister == null) throw const LyricsSourceSkipped();
    try {
      return await _run(installId, script, input, http, read, cancel);
    } finally {
      unregister();
    }
  }

  Future<T> _run<T>(
    String installId,
    PluginScript script,
    Object? input,
    LyricsHttp http,
    T Function(String, List<String>) read,
    PluginCancel cancel,
  ) async {
    final row = await _db.lyricsPluginById(installId);
    if (row == null || row.removedAt != null) {
      throw const LyricsSourceSkipped();
    }
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

    // The outer clock covers the loading as well as the run.
    final clock = Stopwatch()..start();
    final PluginRunSetup setup;
    try {
      setup = await loadPluginRunSetup(
        db: _db,
        packages: _packages,
        dirs: _dirs,
        loadConfig: _loadConfig,
        record: row,
      ).timeout(_outerDeadline);
    } on PluginPackageUnreadable catch (e) {
      throw _failedBeforeRun(event('invalidResponse', e.reason));
    } on PluginRunSetupException catch (e) {
      // Treated like any unreadable input of the plugin: invalid response.
      throw _failedBeforeRun(event('invalidResponse', e.reason));
    } on TimeoutException {
      throw _failedBeforeRun(
        event('network', 'loading the plugin took too long'),
        LyricsFetchKind.network,
      );
    }
    final config = setup.config;
    if (cancel.isCancelled) throw const LyricsSourceSkipped();

    final bridge = PluginFetchBridge(http);
    final left = _outerDeadline - clock.elapsed;
    final (:result, :timedOut) = await runWithDeadline(
      _runtime,
      PluginRunRequest(
        files: setup.package.files,
        entry: script == PluginScript.search
            ? setup.package.searchScript
            : setup.package.lyricsScript,
        inputJson: jsonEncode(input),
        config: config,
        storageJson: setup.storageJson,
      ),
      fetch: bridge.call,
      cancel: cancel,
      deadline: left.isNegative ? Duration.zero : left,
    );
    // Cancelled from outside (an uninstall or update): nothing is written.
    final stopped = cancel.isCancelled && !timedOut;
    if (!stopped && result.storage != null) {
      await savePluginStorage(_db, installId, result.storage!, row.updatedAt);
    }

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
    if (stopped) throw const LyricsSourceSkipped();
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
          requests: bridge.requests,
        ),
        config,
        failed: !ok,
      );
    }
    if (failure != null) throw failure;
    return value as T;
  }

  LyricsFetchException _failedBeforeRun(
    PluginRunLogEvent event, [
    LyricsFetchKind kind = LyricsFetchKind.invalidResponse,
  ]) {
    recordPluginRun(_runLog, event, const {}, failed: true);
    return LyricsFetchException(kind);
  }
}
