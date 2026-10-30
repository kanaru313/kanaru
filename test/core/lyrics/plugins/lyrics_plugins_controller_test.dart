import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';

import '../../database/lyrics_plugin_test_helpers.dart';
import 'package/package_test_helpers.dart';
import 'store/store_test_env.dart';

const file = PluginInstallSource.file('demo.zip');

void main() {
  late StoreEnv env;
  late LyricsPluginsController controller;

  setUp(() async {
    env = await StoreEnv.create();
    controller = env.controller;
  });
  tearDown(() => env.dispose());

  test('the sweep runs before a queued install', () async {
    await env.controller.ready;
    final stray = env.packageDir('plugin-strayxxxxxxx/v1-1');
    await stray.create(recursive: true);
    await env.logs.create(recursive: true);
    await File('${env.logs.path}/plugin-strayxxxxxxx.jsonl').writeAsString('x');

    final second = env.newController();
    final record = await second.installPackage(testPackage(), file);
    expect(await stray.exists(), isFalse);
    expect(await env.packageDir(record.packageDir).exists(), isTrue);
    expect(
      File('${env.logs.path}/plugin-strayxxxxxxx.jsonl').existsSync(),
      isFalse,
    );
  });

  test('the sweep keeps the logs of installed plugins', () async {
    final record = await controller.installPackage(testPackage(), file);
    await env.logs.create(recursive: true);
    final log = File('${env.logs.path}/${record.installId}.jsonl')
      ..writeAsStringSync('x');
    await env.newController().ready;
    expect(log.existsSync(), isTrue);
  });

  test('an install queued behind an uninstall waits for it', () async {
    final a = await controller.installPackage(testPackage(), file);
    // A run that ends only after the cancel wait keeps the uninstall busy.
    env.runs.register(a.installId, PluginCancel());
    final order = <String>[];
    final uninstall = controller
        .uninstall(a.installId)
        .then((_) => order.add('uninstall'));
    final install = controller
        .installPackage(testPackage(name: 'B'), file)
        .then((_) => order.add('install'));
    await Future.wait([uninstall, install]);
    expect(order, ['uninstall', 'install']);
    expect((await env.db.watchLyricsPluginRecords().first).single.name, 'B');
  });

  test('a failed job does not stop the queue', () async {
    await env.db.customStatement(
      'CREATE TRIGGER fail_insert BEFORE INSERT ON lyrics_plugins '
      "BEGIN SELECT RAISE(ABORT, 'boom'); END",
    );
    await expectLater(
      controller.installPackage(testPackage(), file),
      throwsA(anything),
    );
    await env.db.customStatement('DROP TRIGGER fail_insert');
    expect((await controller.installPackage(testPackage(), file)).name, 'Demo');
  });

  test(
    'installFromBytes reports a refused package and writes nothing',
    () async {
      final result = await controller.installFromBytes(
        validZip(manifest: {...validManifest(), 'script': {}}),
        file,
      );
      expect(result, isA<PluginInstallRejected>());
      expect(await env.db.watchLyricsPluginRecords().first, isEmpty);
      expect(env.root.existsSync(), isFalse);
    },
  );

  test('installFromFile installs a real zip under the file name', () async {
    final zip = File('${env.dataDir.path}/lyrics-demo.zip')
      ..writeAsBytesSync(validZip());
    final result = await controller.installFromFile(zip.path);
    final record = (result as PluginInstalled).record;
    expect(record.sourceName, 'lyrics-demo.zip');
    expect(record.name, 'Demo');
    expect(record.hosts, ['music.example.com']);
    expect(
      await controller.installFromFile(env.dataDir.path),
      isA<PluginInstallRejected>(),
    );
  });

  test('updateFromBytes on a missing plugin says gone', () async {
    expect(
      await controller.updateFromBytes('plugin-zzzzzzzzzzzz', validZip()),
      isA<PluginInstallGone>(),
    );
  });

  test('enable, reorder and the clear actions', () async {
    final a = await controller.installPackage(testPackage(), file);
    final b = await controller.installPackage(testPackage(), file);
    expect(
      await controller.setEnabled(a.installId, false),
      LyricsPluginWrite.written,
    );
    final order = await controller.reorder([b.installId, 'lrclib']);
    expect(order.written, [b.installId, 'lrclib']);
    final prefs = await env.db.watchLyricsSourcePrefs().first;
    expect(prefs.map((p) => p.providerId).take(2), [b.installId, 'lrclib']);
    expect(
      prefs.firstWhere((p) => p.providerId == a.installId).enabled,
      isFalse,
    );

    await env.db.setLyricsPluginStorage(a.installId, {
      'k': 'v',
    }, expectedUpdatedAt: a.updatedAt);
    await seedPluginReferences(env.db, a.installId, pin: true);
    expect(
      await controller.clearStorage(a.installId),
      LyricsPluginWrite.written,
    );
    expect((await env.db.lyricsPluginDataFor(a.installId))!.storage, '{}');
    expect(await controller.clearSavedLyrics(a.installId), 2);
    expect(await countRows(env.db, 'lyrics_pins'), 1);
    expect(
      await controller.clearStorage('plugin-zzzzzzzzzzzz'),
      LyricsPluginWrite.skipped,
    );
  });

  test('watchRecords shows removed records too', () async {
    final a = await controller.installPackage(testPackage(), file);
    await seedPluginReferences(env.db, a.installId);
    await controller.uninstall(a.installId);
    final records = await controller.watchRecords().first;
    expect(records.single.isRemoved, isTrue);
  });
}
