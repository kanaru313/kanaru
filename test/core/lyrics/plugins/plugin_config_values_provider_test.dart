import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_config_values_provider.dart';

import 'store/store_test_env.dart';

void main() {
  late StoreEnv env;
  late ProviderContainer container;

  setUp(() async {
    env = await StoreEnv.create();
    container = ProviderContainer(
      overrides: [libraryDatabaseProvider.overrideWithValue(env.db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await env.dispose();
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test(
    'emits the stored values again when a config value is written',
    () async {
      final p = await env.controller.installPackage(
        testPackage(config: [regionField]),
        testRepoSource,
      );
      final seen = <Map<String, Object?>>[];
      container.listen(
        pluginStoredConfigProvider(p.installId),
        (_, next) => next.whenData(seen.add),
        fireImmediately: true,
      );
      await settle();
      expect(seen.last, isEmpty);
      await env.controller.setConfigValue(p.installId, 'region', 'us');
      await settle();
      expect(seen.last, {'region': 'us'});
      expect(seen.length, 2);
    },
  );

  test('does not emit when only the script storage is written', () async {
    final p = await env.controller.installPackage(
      testPackage(config: [regionField]),
      testRepoSource,
    );
    final seen = <Map<String, Object?>>[];
    container.listen(
      pluginStoredConfigProvider(p.installId),
      (_, next) => next.whenData(seen.add),
      fireImmediately: true,
    );
    await settle();
    final count = seen.length;
    final row = (await env.db.lyricsPluginById(p.installId))!;
    await env.db.setLyricsPluginStorage(p.installId, {
      'cursor': 1,
    }, expectedUpdatedAt: row.updatedAt);
    await settle();
    expect(seen.length, count);
    // The same text written again is no change either.
    await env.controller.setConfigValue(p.installId, 'region', 'us');
    await settle();
    final after = seen.length;
    await env.controller.setConfigValue(p.installId, 'region', 'us');
    await settle();
    expect(seen.length, after);
  });

  test('is empty without a database', () async {
    final bare = ProviderContainer();
    addTearDown(bare.dispose);
    bare.listen(pluginStoredConfigProvider('x'), (_, _) {});
    await settle();
    expect(bare.read(pluginStoredConfigProvider('x')).value, isEmpty);
  });
}
