import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_log_paths.dart';
import 'package:kanaru/core/lyrics/plugins/store/lyrics_plugin_dirs.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_install_id.dart';

import '../../../database/lyrics_plugin_test_helpers.dart';
import 'store_test_env.dart';

void main() {
  late Directory tmp;
  late LyricsPluginDirs dirs;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kanaru-dirs-');
    dirs = LyricsPluginDirs(tmp.path);
  });
  tearDown(() => tmp.delete(recursive: true));

  test('root is <data>/plugins/lyrics', () {
    expect(dirs.root.path, '${tmp.path}/plugins/lyrics');
  });

  test('writePackage writes manifest, icon and scripts', () async {
    final package = testPackage(config: [secretField], icon: [1, 2, 3]);
    await dirs.writePackage('plugin-aaaaaaaaaaaa/v1-5', package);
    final dir = dirs.resolve('plugin-aaaaaaaaaaaa/v1-5').path;
    final manifest = jsonDecode(
      await File('$dir/plugin.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(manifest['metadata']['name'], 'Demo');
    expect(manifest['script'], {'search': 'search.js', 'lyrics': 'lyrics.js'});
    expect(manifest['config']['token']['format'], 'secret');
    expect(await File('$dir/src/search.js').readAsString(), '// search');
    expect(await File('$dir/icon.png').readAsBytes(), [1, 2, 3]);
  });

  test('writePackage refuses a path in a script name and cleans up', () async {
    final bad = testPackage(
      files: {'../x.js': '', 'search.js': '', 'lyrics.js': ''},
    );
    await expectLater(
      dirs.writePackage('plugin-aaaaaaaaaaaa/v1-5', bad),
      throwsArgumentError,
    );
    expect(await dirs.resolve('plugin-aaaaaaaaaaaa/v1-5').exists(), isFalse);
  });

  test('freshPackageDir skips a taken name', () async {
    await dirs.resolve('plugin-aaaaaaaaaaaa/v1-5').create(recursive: true);
    expect(
      await dirs.freshPackageDir('plugin-aaaaaaaaaaaa', 1, 5),
      'plugin-aaaaaaaaaaaa/v1-6',
    );
    expect(
      await dirs.freshPackageDir('plugin-aaaaaaaaaaaa', 2, 5),
      'plugin-aaaaaaaaaaaa/v2-5',
    );
  });

  test('sweep keeps referenced folders and removes the rest', () async {
    for (final p in [
      'plugin-aaaaaaaaaaaa/v1-1',
      'plugin-aaaaaaaaaaaa/v2-2',
      'plugin-bbbbbbbbbbbb/v1-1',
    ]) {
      await dirs.resolve(p).create(recursive: true);
    }
    await File('${dirs.root.path}/stray.txt').writeAsString('x');
    final removed = await dirs.sweep({'plugin-aaaaaaaaaaaa/v2-2'});
    expect(removed, 4); // two versions, plugin-b folder, stray file
    expect(await dirs.resolve('plugin-aaaaaaaaaaaa/v2-2').exists(), isTrue);
    expect(await dirs.resolve('plugin-aaaaaaaaaaaa/v1-1').exists(), isFalse);
    expect(
      await Directory('${dirs.root.path}/plugin-bbbbbbbbbbbb').exists(),
      isFalse,
    );
    expect(await File('${dirs.root.path}/stray.txt').exists(), isFalse);
  });

  test('sweep removes a symbolic link without following it', () async {
    final outside = await Directory('${tmp.path}/outside').create();
    await File('${outside.path}/keep.txt').writeAsString('x');
    await Directory('${dirs.root.path}/plugin-aaaaaaaaaaaa')
        .create(recursive: true);
    await Link('${dirs.root.path}/plugin-aaaaaaaaaaaa/v1-1')
        .create(outside.path);
    await dirs.sweep({});
    expect(await File('${outside.path}/keep.txt').exists(), isTrue);
    expect(
      await Directory('${dirs.root.path}/plugin-aaaaaaaaaaaa').exists(),
      isFalse,
    );
  });

  test('sweep with no root folder is a no-op', () async {
    expect(await dirs.sweep({}), 0);
  });

  test(
    'deletePackageDir keeps the plugin folder while others remain',
    () async {
      await dirs.resolve('plugin-aaaaaaaaaaaa/v1-1').create(recursive: true);
      await dirs.resolve('plugin-aaaaaaaaaaaa/v2-2').create(recursive: true);
      await dirs.deletePackageDir('plugin-aaaaaaaaaaaa/v1-1');
      expect(await dirs.resolve('plugin-aaaaaaaaaaaa/v2-2').exists(), isTrue);
      await dirs.deletePackageDir('plugin-aaaaaaaaaaaa/v2-2');
      expect(
        await Directory('${dirs.root.path}/plugin-aaaaaaaaaaaa').exists(),
        isFalse,
      );
    },
  );

  group('install id', () {
    test('has the plugin- prefix and 12 lower-case characters', () {
      final id = newPluginInstallId();
      expect(pluginInstallIdPattern.hasMatch(id), isTrue, reason: id);
      expect(newPluginInstallId(Random(1)), newPluginInstallId(Random(1)));
    });

    test('unique id skips an id already in the database', () async {
      final env = await StoreEnv.create();
      addTearDown(env.dispose);
      final taken = newPluginInstallId(Random(7));
      await env.db.insertLyricsPlugin(taken, pluginSpec(), now: 1);
      final fresh = await uniquePluginInstallId(env.db, Random(7));
      expect(fresh, isNot(taken));
      expect(pluginInstallIdPattern.hasMatch(fresh), isTrue);
    });
  });

  group('log files', () {
    const id = 'plugin-abcdefghijkl';
    late Directory logs;

    setUp(() async {
      logs = await Directory('${tmp.path}/plugin-logs').create();
      for (final name in [
        '$id.jsonl',
        '$id.jsonl.1',
        'plugin-abcdefghijklm.jsonl',
        'plugin-zzzzzzzzzzzz.jsonl',
        'notes.txt',
      ]) {
        await File('${logs.path}/$name').writeAsString('x');
      }
    });

    test('delete removes only this plugin\'s files', () async {
      expect(await deleteLyricsPluginLogs(logs, id), 2);
      final left = [for (final e in logs.listSync()) e.uri.pathSegments.last]
        ..sort();
      expect(left, [
        'notes.txt',
        'plugin-abcdefghijklm.jsonl',
        'plugin-zzzzzzzzzzzz.jsonl',
      ]);
    });

    test('owners lists plugin ids that have a log', () async {
      expect(await lyricsPluginLogOwners(logs), {id, 'plugin-zzzzzzzzzzzz'});
    });

    test('file path only for a plugin id', () {
      expect(lyricsPluginLogFile(logs, id)!.path, '${logs.path}/$id.jsonl');
      expect(lyricsPluginLogFile(logs, '../etc'), isNull);
    });
  });

  test('path helpers refuse names that are not plugin folders', () async {
    expect(() => dirs.resolve('../x/v1-1'), throwsArgumentError);
    expect(
      () => dirs.resolve('plugin-aaaaaaaaaaaa/../v1-1'),
      throwsArgumentError,
    );
    final outside = await Directory('${tmp.path}/outside').create();
    expect(await dirs.deleteInstallTree('../outside'), isFalse);
    await dirs.deletePackageDir('../../outside');
    expect(await outside.exists(), isTrue);
  });

  test('sweep goes on past a folder it cannot read', () async {
    await dirs.resolve('plugin-aaaaaaaaaaaa/v1-1').create(recursive: true);
    await dirs.resolve('plugin-bbbbbbbbbbbb/v1-1').create(recursive: true);
    final locked = '${dirs.root.path}/plugin-aaaaaaaaaaaa';
    await Process.run('chmod', ['000', locked]);
    try {
      await dirs.sweep({});
    } finally {
      await Process.run('chmod', ['755', locked]);
    }
    expect(
      await Directory('${dirs.root.path}/plugin-bbbbbbbbbbbb').exists(),
      isFalse,
    );
  });
}
