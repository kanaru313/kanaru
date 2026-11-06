import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/store/lyrics_plugin_dirs.dart';
import 'package:kanaru/core/lyrics/plugins/store/lyrics_plugin_translate_spec_backfill.dart';

import 'store_test_env.dart';

void main() {
  late StoreEnv env;
  late LyricsPluginDirs dirs;

  setUp(() async {
    env = await StoreEnv.create();
    dirs = LyricsPluginDirs(env.dataDir.path);
  });
  tearDown(() => env.dispose());

  const select = [PluginConfigOption(value: 'a', title: 'A')];
  const aiFields = [
    PluginConfigField(
      key: 'model',
      title: 'Model',
      mode: PluginConfigMode.select,
      options: select,
    ),
    PluginConfigField(
      key: 'style',
      title: 'Style',
      mode: PluginConfigMode.select,
      options: select,
    ),
    PluginConfigField(
      key: 'customInstruction',
      title: 'Instruction',
      mode: PluginConfigMode.input,
    ),
  ];

  Future<String> install({
    PluginKind kind = PluginKind.translate,
    String name = 'Tr',
    PluginInstallSource source = testRepoSource,
  }) async {
    final record = await env.controller.installPackage(
      testPackage(
        kind: kind,
        name: name,
        config: kind == PluginKind.aiTranslate ? aiFields : const [],
      ),
      source,
    );
    return record.installId;
  }

  Future<String?> specOf(String id) async =>
      (await env.db.lyricsPluginById(id))!.translateSpec;

  Future<void> clearSpecs() =>
      env.db.customStatement('UPDATE lyrics_plugins SET translate_spec = NULL');

  test(
    'a NULL column is filled from plugin.json, updated_at untouched',
    () async {
      final id = await install();
      await clearSpecs();
      final before = (await env.db.lyricsPluginById(id))!.updatedAt;
      await backfillTranslateSpecs(env.db, dirs);
      expect(await specOf(id), contains('"vi"'));
      expect((await env.db.lyricsPluginById(id))!.updatedAt, before);
    },
  );

  test(
    'an ai-translate plugin is filled too, a lyrics plugin is not',
    () async {
      final ai = await install(kind: PluginKind.aiTranslate);
      final lyrics = await install(
        kind: PluginKind.lyrics,
        name: 'L',
        source: const PluginInstallSource.file('l.zip'),
      );
      await clearSpecs();
      await backfillTranslateSpecs(env.db, dirs);
      expect(await specOf(ai), isNotNull);
      expect(await specOf(lyrics), isNull);
    },
  );

  test('a column that is already set is not rewritten', () async {
    final id = await install();
    await env.db.customStatement(
      'UPDATE lyrics_plugins SET translate_spec = \'{"keep":1}\'',
    );
    await backfillTranslateSpecs(env.db, dirs);
    expect(await specOf(id), '{"keep":1}');
  });

  test('a missing or broken manifest keeps NULL and does not throw', () async {
    final missing = await install(name: 'A');
    final broken = await install(
      name: 'B',
      source: const PluginInstallSource.file('b.zip'),
    );
    await clearSpecs();
    final missingDir = (await env.db.lyricsPluginById(missing))!.packageDir;
    final brokenDir = (await env.db.lyricsPluginById(broken))!.packageDir;
    dirs.resolve(missingDir).deleteSync(recursive: true);
    File('${dirs.resolve(brokenDir).path}/plugin.json')
        .writeAsStringSync('{not json');
    await backfillTranslateSpecs(env.db, dirs);
    expect(await specOf(missing), isNull);
    expect(await specOf(broken), isNull);
  });

  test('a package_dir that is not a package folder is skipped', () async {
    final id = await install();
    await clearSpecs();
    await env.db.customStatement(
      "UPDATE lyrics_plugins SET package_dir = '../../etc'",
    );
    await backfillTranslateSpecs(env.db, dirs);
    expect(await specOf(id), isNull);
  });

  test('a removed record is skipped', () async {
    final id = await install();
    await env.db.customStatement('UPDATE lyrics_plugins SET removed_at = 5');
    await clearSpecs();
    await backfillTranslateSpecs(env.db, dirs);
    expect(await specOf(id), isNull);
  });

  test('a new controller fills the column before ready completes', () async {
    final id = await install();
    await clearSpecs();
    final next = env.newController();
    await next.ready;
    expect(await specOf(id), isNotNull);
  });
}
