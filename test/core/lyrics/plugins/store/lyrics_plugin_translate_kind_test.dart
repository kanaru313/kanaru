import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest_parser.dart';

import '../../../database/lyrics_plugin_test_helpers.dart';
import 'store_test_env.dart';

PluginConfigField get subtitled => const PluginConfigField(
  key: 'token',
  title: 'Token',
  subtitle: 'line one\nline two',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.secret,
);

void main() {
  late StoreEnv env;
  setUp(() async => env = await StoreEnv.create());
  tearDown(() => env.dispose());

  test('a translate install keeps type, script and translate block', () async {
    final record = await env.controller.installPackage(
      testPackage(kind: PluginKind.translate, config: [subtitled]),
      testRepoSource,
    );
    final row = await env.db.lyricsPluginById(record.installId);
    expect(row!.kind, 'translate');
    expect(record.kind, PluginKind.translate);
    final json = File('${env.packageDir(record.packageDir).path}/plugin.json')
        .readAsBytesSync();
    final manifest = parsePluginManifest(Uint8List.fromList(json));
    expect(manifest.kind, PluginKind.translate);
    expect(manifest.translateScript, 'translate.js');
    expect(manifest.searchScript, isNull);
    expect(manifest.translate!.languages, ['vi', 'en']);
    expect(manifest.config.single.subtitle, 'line one\nline two');
    expect(record.config.single.subtitle, 'line one\nline two');
    expect(jsonDecode(utf8.decode(json))['script'], {
      'translate': 'translate.js',
    });
  });

  test('a translate install writes no source preference row', () async {
    await env.controller.installPackage(
      testPackage(kind: PluginKind.translate),
      testRepoSource,
    );
    expect(await countRows(env.db, 'lyrics_source_prefs'), 0);
  });

  test('a lyrics install reads back as lyrics', () async {
    final record = await env.controller.installPackage(
      testPackage(),
      const PluginInstallSource.file('a.zip'),
    );
    expect((await env.db.lyricsPluginById(record.installId))!.kind, 'lyrics');
  });

  test('a live update to another kind is refused, secrets kept', () async {
    final record = await env.controller.installPackage(
      testPackage(config: [secretField]),
      testRepoSource,
    );
    await env.controller.setConfigValue(record.installId, 'token', 'sekrit');
    await expectLater(
      env.controller.updatePackage(
        record.installId,
        testPackage(kind: PluginKind.translate, version: 2),
      ),
      throwsA(
        isA<PluginUpdateRefusedException>().having(
          (e) => e.reason,
          'reason',
          PluginUpdateRefusal.kindChanged,
        ),
      ),
    );
    expect(env.secrets.values.values, ['sekrit']);
    final row = await env.db.lyricsPluginById(record.installId);
    expect(row!.kind, 'lyrics');
    expect(row.version, 1);
  });

  test('a revive may write another kind', () async {
    final first = await env.controller.installPackage(
      testPackage(),
      testRepoSource,
    );
    await seedPluginReferences(env.db, first.installId);
    await env.controller.uninstall(first.installId);
    final again = await env.controller.installPackage(
      testPackage(kind: PluginKind.translate, version: 2),
      testRepoSource,
    );
    expect(again.installId, first.installId);
    expect(again.kind, PluginKind.translate);
    expect(await countRows(env.db, 'lyrics_source_prefs'), 0);
  });

  test('uninstall keeps the record while a translation names it', () async {
    final record = await env.controller.installPackage(
      testPackage(kind: PluginKind.translate),
      testRepoSource,
    );
    await insertTranslation(env.db, record.installId);
    expect(
      await env.controller.uninstall(record.installId),
      LyricsPluginUninstall.markedRemoved,
    );
    expect(await countRows(env.db, 'lyric_translations'), 1);
    final row = await env.db.lyricsPluginById(record.installId);
    expect(row!.removedAt, isNotNull);

    final again = await env.controller.installPackage(
      testPackage(kind: PluginKind.translate, version: 2),
      testRepoSource,
    );
    expect(again.installId, record.installId, reason: 'cache is reused');
    expect(await countRows(env.db, 'lyric_translations'), 1);
  });

  test('uninstall deletes a translate record nothing names', () async {
    final record = await env.controller.installPackage(
      testPackage(kind: PluginKind.translate),
      testRepoSource,
    );
    expect(
      await env.controller.uninstall(record.installId),
      LyricsPluginUninstall.deleted,
    );
    expect(await env.db.lyricsPluginById(record.installId), isNull);
  });

  test('a revive from translate to lyrics writes one preference row', () async {
    final first = await env.controller.installPackage(
      testPackage(kind: PluginKind.translate),
      testRepoSource,
    );
    await insertTranslation(env.db, first.installId);
    await env.controller.uninstall(first.installId);
    final again = await env.controller.installPackage(
      testPackage(version: 2),
      testRepoSource,
    );
    expect(again.installId, first.installId);
    expect(again.kind, PluginKind.lyrics);
    final prefs = await env.db.watchLyricsSourcePrefs().first;
    expect(prefs.single.providerId, first.installId);
    expect(prefs.single.enabled, isTrue);
  });
}
