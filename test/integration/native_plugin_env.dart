import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_reader.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_lyrics_provider.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_log_paths.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_log.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_registry.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_script_runner.dart';
import 'package:kanaru/core/lyrics/plugins/store/lyrics_plugin_dirs.dart';
import 'package:kanaru/core/plugin_runtime/rust_plugin_runtime.dart';
import 'package:kanaru/core/secrets/secret_store_provider.dart'
    show ResolvedSecretStore;
import 'package:kanaru/src/rust/frb_generated.dart';

import '../core/lyrics/plugins/store/store_test_env.dart' show FakeSecretStore;

/// The debug library `cargo build --manifest-path rust/Cargo.toml` makes.
final nativeLibraryPath =
    '${Directory.current.path}/rust/target/debug/'
    'librust_lib_kanaru.so';

/// Why the native tests cannot run, or `null` when they can. Set by
/// [initNativeLibrary].
String? nativeSkipReason;

/// Loads the cargo-built library once per test isolate and sets
/// [nativeSkipReason] when that is not possible (file missing, or a stale
/// build the bridge refuses). Call it from `setUpAll`.
Future<void> initNativeLibrary() async {
  // Every lookup harness opens its own in-memory database on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  if (!File(nativeLibraryPath).existsSync()) {
    nativeSkipReason =
        'Native library not built: run '
        '`cargo build --manifest-path rust/Cargo.toml` first '
        '(expected at $nativeLibraryPath)';
    return;
  }
  if (RustLib.instance.initialized) return;
  try {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(nativeLibraryPath),
    );
  } on Object catch (error) {
    nativeSkipReason =
        'Native library cannot be loaded (${error.runtimeType}); rebuild '
        'with `cargo build --manifest-path rust/Cargo.toml`';
  }
}

/// A test that is reported skipped, with the reason, when the native library
/// is not available.
void nativeTest(String name, Future<void> Function() body, {Timeout? timeout}) {
  test(name, () async {
    final reason = nativeSkipReason;
    if (reason != null) {
      markTestSkipped(reason);
      return;
    }
    await body();
  }, timeout: timeout);
}

/// A real data folder, database, plugin controller (with the real native
/// package check) and script runner on the real native runtime. Only the
/// network (an `HttpClient` the test passes to the lookup) and the secret
/// store are replaced.
class NativePluginEnv {
  NativePluginEnv._(this.dataDir, this.db, this.controller, this.runner);

  final Directory dataDir;
  final LibraryDatabase db;
  final LyricsPluginsController controller;
  final PluginScriptRunner runner;

  /// [outerDeadline] is how long a run may take in all.
  static Future<NativePluginEnv> create({Duration? outerDeadline}) async {
    final dir = await Directory.systemTemp.createTemp('kanaru-integration-');
    final db = LibraryDatabase(NativeDatabase.memory());
    const runtime = RustPluginRuntime();
    final runs = PluginRunRegistry();
    final secrets = FakeSecretStore();
    final controller = LyricsPluginsController(
      db: db,
      dataDirectory: dir.path,
      secretStore: () async =>
          ResolvedSecretStore(secrets, usingFallback: false, persistent: true),
      reader: const PluginPackageReader(runtime),
      runs: runs,
    );
    await controller.ready;
    final runner = PluginScriptRunner(
      db: db,
      runtime: runtime,
      runs: runs,
      runLog: PluginRunLog(lyricsPluginLogDirOf(dir.path)),
      dirs: LyricsPluginDirs(dir.path),
      loadConfig: controller.configForRun,
      outerDeadline: outerDeadline ?? const Duration(seconds: 60),
    );
    return NativePluginEnv._(dir, db, controller, runner);
  }

  /// Installs [zip] through the real reader (manifest checks and the native
  /// syntax check of every script) and returns the outcome.
  Future<PluginInstallOutcome> tryInstall(Uint8List zip) => controller
      .installFromBytes(zip, const PluginInstallSource.file('fixture.zip'));

  /// Installs [zip]; fails the test when it is not accepted.
  Future<LyricsPluginRecord> install(Uint8List zip) async {
    final outcome = await tryInstall(zip);
    if (outcome is! PluginInstalled) {
      throw StateError('the package was not installed: $outcome');
    }
    return outcome.record;
  }

  PluginLyricsProvider providerFor(LyricsPluginRecord record) =>
      PluginLyricsProvider(record, runner);

  /// The events in the plugin's log file, in order.
  Future<List<Map<String, Object?>>> events(String installId) async {
    await PluginRunLog.idle();
    final file = File(
      '${lyricsPluginLogDirOf(dataDir.path).path}/$installId.jsonl',
    );
    if (!file.existsSync()) return const [];
    return [
      for (final line in file.readAsLinesSync())
        jsonDecode(line) as Map<String, Object?>,
    ];
  }

  Future<void> dispose() async {
    await PluginRunLog.idle();
    await db.close();
    if (dataDir.existsSync()) await dataDir.delete(recursive: true);
  }
}
