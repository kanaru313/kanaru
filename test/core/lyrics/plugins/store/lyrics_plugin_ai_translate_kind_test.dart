import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';

import '../../../database/lyrics_plugin_test_helpers.dart';
import 'store_test_env.dart';

void main() {
  late StoreEnv env;
  setUp(() async => env = await StoreEnv.create());
  tearDown(() => env.dispose());

  test('an ai-translate install is stored and read back', () async {
    final record = await env.controller.installPackage(
      testPackage(kind: PluginKind.aiTranslate),
      testRepoSource,
    );
    expect(record.kind, PluginKind.aiTranslate);
    expect(
      (await env.db.lyricsPluginById(record.installId))!.kind,
      'ai-translate',
    );
    expect(await countRows(env.db, 'lyrics_source_prefs'), 0);
  });

  test('update translate to ai-translate keeps the id and the cache', () async {
    final record = await env.controller.installPackage(
      testPackage(kind: PluginKind.translate),
      testRepoSource,
    );
    await insertTranslation(env.db, record.installId);
    final updated = await env.controller.updatePackage(
      record.installId,
      testPackage(kind: PluginKind.aiTranslate, version: 2),
    );
    expect(updated!.installId, record.installId);
    expect(updated.kind, PluginKind.aiTranslate);
    final row = await env.db.lyricsPluginById(record.installId);
    expect(row!.kind, 'ai-translate');
    expect(row.version, 2);
    expect(await countRows(env.db, 'lyric_translations'), 1);
  });

  test('update keeps the id a selected service and its consent are keyed by, and the config', () async {
    final record = await env.controller.installPackage(
      testPackage(kind: PluginKind.translate, config: [textField]),
      testRepoSource,
    );
    await env.controller.setConfigValue(record.installId, 'token', 'abc');
    final updated = await env.controller.updatePackage(
      record.installId,
      testPackage(
        kind: PluginKind.aiTranslate,
        version: 2,
        config: [textField],
      ),
    );
    // The selected service is this id, so it still resolves.
    expect(updated!.installId, record.installId);
    expect(updated.kind!.isTranslation, isTrue);
    final data = (await env.db.lyricsPluginDataFor(record.installId))!;
    expect(data.configValues, contains('abc'));
  });

  test('update ai-translate back to translate writes the kind', () async {
    final record = await env.controller.installPackage(
      testPackage(kind: PluginKind.aiTranslate),
      testRepoSource,
    );
    await env.controller.updatePackage(
      record.installId,
      testPackage(kind: PluginKind.translate, version: 2),
    );
    expect(
      (await env.db.lyricsPluginById(record.installId))!.kind,
      'translate',
    );
  });

  for (final target in [PluginKind.aiTranslate, PluginKind.translate]) {
    test('update lyrics to ${target.value} is refused', () async {
      final record = await env.controller.installPackage(
        testPackage(),
        testRepoSource,
      );
      await expectLater(
        env.controller.updatePackage(
          record.installId,
          testPackage(kind: target, version: 2),
        ),
        throwsA(
          isA<PluginUpdateRefusedException>().having(
            (e) => e.reason,
            'reason',
            PluginUpdateRefusal.kindChanged,
          ),
        ),
      );
      expect((await env.db.lyricsPluginById(record.installId))!.kind, 'lyrics');
    });
  }

  test('update ai-translate to lyrics is refused', () async {
    final record = await env.controller.installPackage(
      testPackage(kind: PluginKind.aiTranslate),
      testRepoSource,
    );
    await expectLater(
      env.controller.updatePackage(record.installId, testPackage(version: 2)),
      throwsA(isA<PluginUpdateRefusedException>()),
    );
  });

  test('a revive may switch translate to ai-translate', () async {
    final first = await env.controller.installPackage(
      testPackage(kind: PluginKind.translate),
      testRepoSource,
    );
    await insertTranslation(env.db, first.installId);
    await env.controller.uninstall(first.installId);
    final again = await env.controller.installPackage(
      testPackage(kind: PluginKind.aiTranslate, version: 2),
      testRepoSource,
    );
    expect(again.installId, first.installId);
    expect(again.kind, PluginKind.aiTranslate);
  });
}
