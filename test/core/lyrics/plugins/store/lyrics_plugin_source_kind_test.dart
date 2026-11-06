import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_reader.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_package_loader.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';

import '../../../database/lyrics_plugin_test_helpers.dart';
import '../package/package_test_helpers.dart';
import 'store_test_env.dart';

/// A runtime that records which files the install-time syntax check saw.
class _RecordingRuntime extends FakeRuntime {
  final checked = <String>[];

  @override
  Future<PluginScriptProblem?> check(String fileName, String code) {
    checked.add(fileName);
    return super.check(fileName, code);
  }
}

Map<String, dynamic> _sourceManifest() => {
  'metadata': {
    'apiVersion': 1,
    'type': 'source',
    'name': 'YouTube',
    'version': 1,
    'hosts': ['www.youtube.com', '*.googlevideo.com'],
  },
  'script': {'search': 'search.js', 'stream': 'stream.js'},
};

void main() {
  late StoreEnv env;
  late _RecordingRuntime runtime;
  setUp(() async {
    env = await StoreEnv.create();
    runtime = _RecordingRuntime();
  });
  tearDown(() => env.dispose());

  Future<PluginPackage> readPackage(Map<String, Object> extra) async {
    final zip = buildZip({
      'plugin.json': jsonEncode(_sourceManifest()),
      'src/search.js': 'function execute(q) { return q; }',
      'src/stream.js': 'function execute(id) { return id; }',
      ...extra,
    });
    final result = await PluginPackageReader(runtime).read(zip);
    return (result as PluginPackageAccepted).package;
  }

  test('a source zip installs and loads back with its stream script', () async {
    final package = await readPackage(const {});
    expect(runtime.checked, containsAll(['search.js', 'stream.js']));

    final record = await env.controller.installPackage(package, testRepoSource);
    expect(record.kind, PluginKind.source);
    expect(record.hosts, ['www.youtube.com', '*.googlevideo.com']);
    expect((await env.db.lyricsPluginById(record.installId))!.kind, 'source');
    expect(await countRows(env.db, 'lyrics_source_prefs'), 0);

    final loaded = await PluginPackageLoader().load(
      record.packageDir,
      env.packageDir(record.packageDir),
    );
    expect(loaded.kind, PluginKind.source);
    expect(loaded.searchScript, 'search.js');
    expect(loaded.streamScript, 'stream.js');
    expect(loaded.lyricsScript, isNull);
    expect(
      loaded.files.map((f) => f.name),
      containsAll(['search.js', 'stream.js']),
    );

    final json = jsonDecode(
      File('${env.packageDir(record.packageDir).path}/plugin.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(json['script'], {'search': 'search.js', 'stream': 'stream.js'});
  });

  test('a source zip without its stream file is missingScript', () async {
    final zip = buildZip({
      'plugin.json': jsonEncode(_sourceManifest()),
      'src/search.js': 'function execute(q) { return q; }',
    });
    final result = await PluginPackageReader(runtime).read(zip);
    final problem = (result as PluginPackageRejected).problem;
    expect(problem.kind, PluginPackageProblemKind.missingScript);
    expect(problem.detail, 'stream.js');
  });

  test('a source zip whose manifest names no stream is invalid', () async {
    final manifest = _sourceManifest();
    (manifest['script'] as Map).remove('stream');
    final result = await PluginPackageReader(runtime).read(
      buildZip({
        'plugin.json': jsonEncode(manifest),
        'src/search.js': 'function execute(q) { return q; }',
      }),
    );
    final problem = (result as PluginPackageRejected).problem;
    expect(problem.kind, PluginPackageProblemKind.invalidManifest);
    expect(problem.detail, 'script.stream');
  });
}
