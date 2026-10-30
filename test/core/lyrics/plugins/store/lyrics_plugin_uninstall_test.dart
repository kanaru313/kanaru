import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';

import '../../../database/lyrics_plugin_test_helpers.dart';
import 'store_test_env.dart';

void main() {
  late StoreEnv env;
  late LyricsPluginRecord plugin;
  late String secretName;

  setUp(() async {
    env = await StoreEnv.create();
    plugin = await env.controller.installPackage(
      testPackage(config: [secretField, regionField]),
      testRepoSource,
    );
    secretName = 'lyrics_plugin.${plugin.installId}.token';
    await env.controller.setConfigValue(plugin.installId, 'token', 'sekrit');
    await env.controller.setConfigValue(plugin.installId, 'region', 'us');
    await env.logs.create(recursive: true);
    for (final suffix in ['.jsonl', '.jsonl.1']) {
      await File('${env.logs.path}/${plugin.installId}$suffix')
          .writeAsString('{}\n');
    }
    await File('${env.logs.path}/plugin-otherotherxx.jsonl').writeAsString('');
  });
  tearDown(() => env.dispose());

  Future<List<String>> logNames() async =>
      [for (final e in env.logs.listSync()) e.uri.pathSegments.last]..sort();

  test('saved lyrics, pin and reject stay; everything else goes', () async {
    await seedPluginReferences(
      env.db,
      plugin.installId,
      pin: true,
      reject: true,
    );
    final result = await env.controller.uninstall(plugin.installId);
    expect(result, LyricsPluginUninstall.markedRemoved);

    final row = await env.db.lyricsPluginById(plugin.installId);
    expect(row!.removedAt, isNotNull);
    expect(await countRows(env.db, 'online_lyrics'), 1, reason: 'found stays');
    expect(
      (await env.db.customSelect('SELECT status FROM online_lyrics').get())
          .single
          .read<String>('status'),
      'found',
    );
    expect(await countRows(env.db, 'lyrics_pins'), 1);
    expect(await countRows(env.db, 'online_lyrics_rejects'), 1);

    expect(await env.db.lyricsPluginDataFor(plugin.installId), isNull);
    expect(await env.db.watchLyricsSourcePrefs().first, isEmpty);
    expect(env.secrets.values.containsKey(secretName), isFalse);
    expect(await env.packageDir(plugin.installId).exists(), isFalse);
    expect(await logNames(), ['plugin-otherotherxx.jsonl']);
  });

  test('with nothing saved the record is deleted', () async {
    await seedPluginReferences(env.db, plugin.installId, found: false);
    expect(
      await env.controller.uninstall(plugin.installId),
      LyricsPluginUninstall.deleted,
    );
    expect(await env.db.lyricsPluginById(plugin.installId), isNull);
    expect(await countRows(env.db, 'online_lyrics'), 0);
  });

  test('undo right after an install deletes the record', () async {
    expect(
      await env.controller.undoInstall(plugin.installId),
      LyricsPluginUninstall.deleted,
    );
    expect(await env.db.watchLyricsPluginRecords().first, isEmpty);
    expect(await env.root.exists() && env.root.listSync().isNotEmpty, isFalse);
  });

  test(
    'a missing or removed plugin changes nothing and keeps secrets',
    () async {
      await seedPluginReferences(env.db, plugin.installId);
      await env.controller.uninstall(plugin.installId);
      // A secret that appeared after the first uninstall is not touched again.
      env.secrets.values[secretName] = 'later';
      expect(
        await env.controller.uninstall(plugin.installId),
        LyricsPluginUninstall.alreadyRemoved,
      );
      expect(env.secrets.values[secretName], 'later');
      expect(
        await env.controller.uninstall('plugin-zzzzzzzzzzzz'),
        LyricsPluginUninstall.missing,
      );
    },
  );

  test('a keyring failure is not an uninstall failure', () async {
    env.secrets.failing = true;
    expect(
      await env.controller.uninstall(plugin.installId),
      LyricsPluginUninstall.deleted,
    );
    expect(await env.db.lyricsPluginById(plugin.installId), isNull);
    expect(await env.packageDir(plugin.installId).exists(), isFalse);
  });

  test(
    'uninstall cancels a running lookup; its late writes are refused',
    () async {
      final cancel = PluginCancel();
      final end = env.runs.register(plugin.installId, cancel)!;
      cancel.addListener(
        () => Future.delayed(const Duration(milliseconds: 20), end),
      );
      await seedPluginReferences(env.db, plugin.installId, notFound: false);
      final startedAt = (await env.db.lyricsPluginById(plugin.installId))!
          .updatedAt;

      await env.controller.uninstall(plugin.installId);
      expect(cancel.isCancelled, isTrue);
      expect(env.runs.runningCount(plugin.installId), 0);

      // The run finishes late and tries to save.
      expect(
        await env.db.setLyricsPluginStorage(plugin.installId, {
          'a': 'b',
        }, expectedUpdatedAt: startedAt),
        LyricsPluginWrite.skipped,
      );
      final saved = await env.db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: 'late',
          providerId: plugin.installId,
          status: 'found',
          fetchedAt: 1,
        ),
      );
      expect(saved, isFalse);
    },
  );

  test('update cancels runs before the switch', () async {
    final cancel = PluginCancel();
    final end = env.runs.register(plugin.installId, cancel)!;
    cancel.addListener(end);
    await env.controller.updatePackage(
      plugin.installId,
      testPackage(version: 2, config: [secretField, regionField]),
    );
    expect(cancel.isCancelled, isTrue);
  });

  test('new runs are refused while an uninstall changes the plugin', () async {
    env.runs.register(plugin.installId, PluginCancel()); // never ends
    final uninstall = env.controller.uninstall(plugin.installId);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(env.runs.isBlocked(plugin.installId), isTrue);
    expect(env.runs.register(plugin.installId, PluginCancel()), isNull);
    await uninstall;
    expect(env.runs.isBlocked(plugin.installId), isFalse);
  });

  test('new runs are refused while an update switches the package', () async {
    env.runs.register(plugin.installId, PluginCancel()); // never ends
    final update = env.controller.updatePackage(
      plugin.installId,
      testPackage(version: 2, config: [secretField, regionField]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(env.runs.register(plugin.installId, PluginCancel()), isNull);
    await update;
    expect(env.runs.isBlocked(plugin.installId), isFalse);
    expect(env.runs.register(plugin.installId, PluginCancel()), isNotNull);
  });
}
