import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_reader.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_registry.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';
import 'package:kanaru/core/secrets/secret_store_provider.dart';

/// A secret store that records calls and can be made to fail.
class FakeSecretStore implements SecretStore {
  final Map<String, String> values = {};
  int reads = 0;
  bool failing = false;

  void _check() {
    if (failing) {
      throw const SecretStoreException(SecretStoreFailure.locked);
    }
  }

  @override
  Future<String?> read(String key) async {
    reads++;
    _check();
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _check();
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _check();
    values.remove(key);
  }
}

/// A runtime whose syntax check passes (or hangs, to test the time limit).
class FakeRuntime implements PluginRuntime {
  FakeRuntime({this.hang = false});

  final bool hang;

  @override
  Future<PluginScriptProblem?> check(String fileName, String code) => hang
      ? Future<PluginScriptProblem?>.delayed(const Duration(days: 1))
      : Future.value();

  @override
  Future<PluginRunResult> run(
    PluginRunRequest request, {
    required PluginFetcher fetch,
    PluginCancel? cancel,
  }) => throw UnimplementedError();
}

/// A checked package built in memory.
PluginPackage testPackage({
  String name = 'Demo',
  int version = 1,
  List<PluginConfigField> config = const [],
  Map<String, String>? files,
  List<int>? icon,
}) => PluginPackage(
  manifest: PluginManifest(
    apiVersion: 1,
    name: name,
    version: version,
    hosts: const ['api.example.com'],
    searchScript: 'search.js',
    lyricsScript: 'lyrics.js',
    author: 'someone',
    config: config,
  ),
  files: files ?? {'search.js': '// search', 'lyrics.js': '// lyrics'},
  icon: icon == null ? null : Uint8List.fromList(icon),
);

const secretField = PluginConfigField(
  key: 'token',
  title: 'Token',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.secret,
);
const textField = PluginConfigField(
  key: 'token',
  title: 'Token',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.text,
);
const regionField = PluginConfigField(
  key: 'region',
  title: 'Region',
  mode: PluginConfigMode.select,
  options: [
    PluginConfigOption(value: 'eu', title: 'EU'),
    PluginConfigOption(value: 'us', title: 'US'),
  ],
  defaultValue: 'eu',
);

/// A repo source, for plugins that must be updatable.
const testRepoSource = PluginInstallSource.repo(
  name: 'Official',
  repoUrl: 'https://repo.example.com/index.json',
  repoSlug: 'demo',
);

/// A controller on a temp data folder, an in-memory database and a fake
/// secret store.
class StoreEnv {
  StoreEnv._(this.dataDir, this.db, this.secrets, this.runs, this.clockMs);

  final Directory dataDir;
  final LibraryDatabase db;
  final FakeSecretStore secrets;
  final PluginRunRegistry runs;
  final List<int> clockMs;
  late LyricsPluginsController controller;

  static Future<StoreEnv> create({
    Duration cancelWait = const Duration(milliseconds: 200),
  }) async {
    final dir = await Directory.systemTemp.createTemp('kanaru-plugins-');
    final env = StoreEnv._(
      dir,
      LibraryDatabase(NativeDatabase.memory()),
      FakeSecretStore(),
      PluginRunRegistry(cancelWait: cancelWait),
      [1000000],
    );
    env.controller = env.newController();
    return env;
  }

  /// A fresh controller on the same folder and database (a new "session").
  LyricsPluginsController newController() => LyricsPluginsController(
    db: db,
    dataDirectory: dataDir.path,
    secretStore: () async =>
        ResolvedSecretStore(secrets, usingFallback: false, persistent: true),
    reader: PluginPackageReader(FakeRuntime()),
    runs: runs,
    clock: () {
      clockMs[0] += 1000;
      return DateTime.fromMillisecondsSinceEpoch(clockMs[0]);
    },
  );

  Directory get root => Directory('${dataDir.path}/plugins/lyrics');
  Directory get logs => Directory('${dataDir.path}/plugin-logs');

  Directory packageDir(String relative) => Directory('${root.path}/$relative');

  Future<void> dispose() async {
    await db.close();
    if (await dataDir.exists()) await dataDir.delete(recursive: true);
  }
}
