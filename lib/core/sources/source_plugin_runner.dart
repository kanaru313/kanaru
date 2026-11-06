import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/lyrics_plugin_queries.dart';
import '../lyrics/online/lyrics_http.dart';
import '../lyrics/online/lyrics_http_retry.dart'
    show LyricsSleep, realLyricsSleep;
import '../lyrics/online/online_lyrics_http_factory.dart'
    show lyricsHttpClientProvider;
import '../lyrics/plugins/lyrics_plugin_record.dart';
import '../lyrics/plugins/plugin_log_paths.dart';
import '../lyrics/plugins/plugin_package_loader.dart';
import '../lyrics/plugins/plugin_run_core.dart';
import '../lyrics/plugins/plugin_run_log.dart';
import '../lyrics/plugins/plugin_script_runner_provider.dart';
import '../settings/settings_provider.dart';
import 'source_models.dart';
import 'source_output_reader.dart';
import 'source_run_log.dart';

export 'source_models.dart';

/// Runs the `search.js` and `stream.js` of an installed source plugin and
/// turns what happens into a checked value or a [SourceFailure].
///
/// * `consented` (the plugin's notice was accepted) and `abandoned` are asked
///   before the run, before every send and once the run is over: without
///   consent nothing runs or is sent (`notConsented`), and once abandoned
///   nothing more is sent (`skipped`);
/// * runs go through the shared [PluginRunCore] (package cache, run
///   registry, outer deadline), so an update or uninstall ends one `skipped`;
/// * `fetch` reaches only the plugin's own hosts, with no re-send of a busy
///   answer;
/// * a failed run, or one that printed, goes to the plugin's log like a
///   lyrics run (never the stream URL or its headers).
class SourcePluginRunner {
  SourcePluginRunner({
    required this._core,
    required this._runLog,
    required this._client,
    required this._consented,
    this._sleep = realLyricsSleep,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PluginRunCore _core;
  final PluginRunLog _runLog;
  final HttpClient Function() _client;
  final bool Function(String installId) _consented;
  final LyricsSleep _sleep;
  final DateTime Function() _clock;

  /// One page of results for [query]; [next] is the `next` of the page
  /// before. Throws [SourceFailure].
  Future<SourceSearchPage> search(
    String installId,
    String query, {
    String? next,
    bool Function()? abandoned,
  }) => _run(
    installId,
    script: 'search.js',
    entry: (package) => package.searchScript,
    input: {'query': query, 'next': ?next},
    abandoned: abandoned,
    read: (json, notes) =>
        readSourceSearchOutput(json, inputNext: next, notes: notes),
  );

  /// Where the audio of [itemId] is. [fresh] asks the plugin to skip its own
  /// cache (the previous URL was refused). Throws [SourceFailure].
  Future<SourceStream> stream(
    String installId,
    String itemId, {
    bool fresh = false,
    bool Function()? abandoned,
  }) => _run(
    installId,
    script: 'stream.js',
    entry: (package) => package.streamScript,
    input: {'id': itemId, if (fresh) 'fresh': true},
    abandoned: abandoned,
    read: (json, _) => readSourceStreamOutput(json),
  );

  Future<T> _run<T>(
    String installId, {
    required String script,
    required String? Function(LoadedPluginPackage package) entry,
    required Map<String, Object?> input,
    required bool Function()? abandoned,
    required T Function(String json, List<String> notes) read,
  }) async {
    bool gone() => abandoned?.call() ?? false;
    bool allowed() => _consented(installId);
    if (gone()) throw const SourceFailure(kind: SourceFailureKind.skipped);
    if (!allowed()) {
      throw const SourceFailure(kind: SourceFailureKind.notConsented);
    }
    final outcome = await _core.run(
      installId: installId,
      kind: PluginKind.source,
      entry: entry,
      input: input,
      http: (row) => LyricsHttp.forPluginSource(
        LyricsPluginRecord.fromRow(row).hosts,
        _client(),
        allowed: allowed,
        abandoned: abandoned,
        sleep: _sleep,
      ),
    );
    final row = outcome.row;
    // Missing, removed, of another kind, being changed, or no such script.
    if (row == null) throw const SourceFailure(kind: SourceFailureKind.skipped);
    // A required field is empty: nothing ran, nothing is logged.
    if (outcome.state == PluginRunState.needsConfig) {
      throw const SourceFailure(kind: SourceFailureKind.needsConfig);
    }
    if (outcome.state == PluginRunState.setupFailed) {
      final kind = outcome.timedOut
          ? SourceFailureKind.network
          : SourceFailureKind.internal;
      recordSourceRun(
        _runLog,
        row: row,
        script: script,
        query: input,
        time: _clock(),
        failure: kind,
        message: outcome.reason,
      );
      throw SourceFailure(kind: kind);
    }
    // Stopped by an update or uninstall: nothing is logged.
    if (outcome.stopped) {
      throw const SourceFailure(kind: SourceFailureKind.skipped);
    }
    final result = outcome.result!;
    var failure = sourceFailureKind(result);
    // Asked once more at the end: what a run brings back after the caller
    // left or the consent was withdrawn is not used.
    if (gone()) {
      failure = SourceFailureKind.skipped;
    } else if (!allowed()) {
      failure = SourceFailureKind.notConsented;
    }
    final notes = <String>[];
    var problem = '';
    T? value;
    if (failure == null) {
      try {
        value = read(result.outputJson, notes);
      } on PluginOutputException catch (e) {
        problem = e.reason;
        failure = SourceFailureKind.invalidOutput;
      }
    }
    final message = sourceFailureMessage(result);
    if (sourceRunIsLogged(failure)) {
      recordFinishedSourceRun(
        _runLog,
        outcome,
        script: script,
        query: input,
        time: _clock(),
        failure: failure,
        problem: problem,
        notes: notes,
      );
    }
    if (failure != null) throw SourceFailure(kind: failure, message: message);
    return value as T;
  }
}

/// Runs source plugins. Shares the run core of the lyrics runner (one
/// package cache and one run registry for every plugin kind). `null` while
/// the library database or the data folder is unavailable.
final sourcePluginRunnerProvider = Provider<SourcePluginRunner?>((ref) {
  final scripts = ref.watch(pluginScriptRunnerProvider);
  final logDir = ref.watch(lyricsPluginLogDirProvider);
  if (scripts == null || logDir == null) return null;
  return SourcePluginRunner(
    core: scripts.core,
    runLog: PluginRunLog(logDir),
    // Read per run: the shared public-only pinned client, restricted to the
    // plugin's own hosts by `LyricsHttp.forPluginSource`.
    client: () {
      try {
        return ref.read(lyricsHttpClientProvider);
      } on Object {
        // The container or this build is gone: the call is dropped.
        throw const SourceFailure(kind: SourceFailureKind.skipped);
      }
    },
    // Read live before every send. Fails closed: when the settings cannot be
    // read (this build is gone), nothing is sent.
    consented: (installId) {
      try {
        return ref.read(settingsProvider).onlineSources.allows(installId);
      } on Object {
        return false;
      }
    },
  );
});
