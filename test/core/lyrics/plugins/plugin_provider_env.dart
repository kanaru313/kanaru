import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_lyrics_provider.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_log.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_deadline.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_script_runner.dart';
import 'package:kanaru/core/lyrics/plugins/store/lyrics_plugin_dirs.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';

import '../online/counting_http_client.dart';
import 'store/store_test_env.dart';

/// Answers a script run. [fetch] is the app's fetcher of the run, [cancel]
/// its token.
typedef ScriptHandler = FutureOr<PluginRunResult> Function(
  PluginRunRequest request,
  PluginFetcher fetch,
  PluginCancel? cancel,
);

/// A runtime whose runs are scripted by entry file name (`search.js`,
/// `lyrics.js`); an entry without a handler answers an empty list.
class ScriptedRuntime implements PluginRuntime {
  final handlers = <String, ScriptHandler>{};
  final requests = <PluginRunRequest>[];

  /// Runs started and not finished.
  int active = 0;

  void onSearch(PluginRunResult result) =>
      handlers['search.js'] = (_, _, _) => result;

  void onLyrics(PluginRunResult result) =>
      handlers['lyrics.js'] = (_, _, _) => result;

  @override
  Future<PluginRunResult> run(
    PluginRunRequest request, {
    required PluginFetcher fetch,
    PluginCancel? cancel,
  }) async {
    requests.add(request);
    active++;
    try {
      final handler = handlers[request.entry];
      if (handler == null) return okResult('[]');
      return await handler(request, fetch, cancel);
    } finally {
      active--;
    }
  }

  @override
  Future<PluginScriptProblem?> check(String fileName, String code) async =>
      null;
}

PluginRunResult okResult(
  String json, {
  List<String> logs = const [],
  String? storage,
  PluginFetchFailure? fetchFailure,
}) => PluginRunResult(
  status: PluginRunStatus.ok,
  outputJson: json,
  logs: logs,
  storage: storage,
  fetchFailure: fetchFailure,
);

/// A runtime handler that waits until the run is cancelled and then answers
/// cancelled, like the real runtime.
ScriptHandler cancelledWhenStopped(Completer<void> started) =>
    (request, fetch, cancel) async {
      final stopped = Completer<void>();
      cancel!.addListener(stopped.complete);
      if (!started.isCompleted) started.complete();
      await stopped.future;
      return const PluginRunResult(status: PluginRunStatus.cancelled);
    };

/// A [LyricsHttp] for the plugin's host that opens no socket.
LyricsHttp countingHttp([CountingHttpClient? client]) => LyricsHttp.forTesting(
  client: client ?? CountingHttpClient(),
  hosts: const ['api.example.com'],
);

/// A real controller, database and data folder with a scripted runtime and
/// a [PluginScriptRunner] on top, to run plugins as a lookup would.
class PluginProviderEnv {
  PluginProviderEnv._(this.store, this.runtime, this.runner);

  final StoreEnv store;
  final ScriptedRuntime runtime;
  final PluginScriptRunner runner;

  LibraryDatabase get db => store.db;
  LyricsPluginsController get controller => store.controller;

  static Future<PluginProviderEnv> create({
    Duration outerDeadline = pluginRunOuterDeadline,
    DateTime Function()? clock,
    Future<Map<String, String>> Function(String installId)? loadConfig,
  }) async {
    final store = await StoreEnv.create();
    final runtime = ScriptedRuntime();
    final runner = PluginScriptRunner(
      db: store.db,
      runtime: runtime,
      runs: store.runs,
      runLog: PluginRunLog(store.logs),
      dirs: LyricsPluginDirs(store.dataDir.path),
      loadConfig: loadConfig ?? store.controller.configForRun,
      outerDeadline: outerDeadline,
      clock: clock,
    );
    return PluginProviderEnv._(store, runtime, runner);
  }

  /// Installs a package named [name] and returns its record.
  Future<LyricsPluginRecord> install({
    String name = 'Demo',
    List<PluginConfigField> config = const [],
    PluginInstallSource? source,
  }) async {
    return controller.installPackage(
      testPackage(name: name, config: config),
      source ?? PluginInstallSource.file('$name.zip'),
    );
  }

  PluginLyricsProvider providerFor(LyricsPluginRecord record) =>
      PluginLyricsProvider(record, runner);

  /// The events in the plugin's log file, in order.
  List<Map<String, Object?>> events(String installId) {
    final file = File('${store.logs.path}/$installId.jsonl');
    if (!file.existsSync()) return const [];
    return [
      for (final line in file.readAsLinesSync())
        jsonDecode(line) as Map<String, Object?>,
    ];
  }

  Future<void> dispose() async {
    await PluginRunLog.idle();
    await store.dispose();
  }
}

/// Lets the log writes the runs started in the background finish.
Future<void> pumpLog() => PluginRunLog.idle();
