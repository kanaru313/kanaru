import 'package:drift/drift.dart' show UpdateKind, Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_source_names.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_log_paths.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_registry.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime_provider.dart';
import 'package:logging/logging.dart';

import 'plugin_provider_env.dart';

LyricsPluginRecord _record(
  String id,
  int installedAt, {
  bool removed = false,
}) => LyricsPluginRecord(
  installId: id,
  name: 'Plugin $id',
  version: 1,
  apiVersion: 1,
  hosts: const ['api.example.com'],
  config: const [],
  packageDir: '$id/v1-1',
  sourceKind: LyricsPluginSourceKind.file,
  sourceName: 'x.zip',
  installedAt: installedAt,
  updatedAt: installedAt,
  removedAt: removed ? 1 : null,
);

LyricsSourcePrefRow _pref(String id, int position, {bool enabled = true}) =>
    LyricsSourcePrefRow(providerId: id, enabled: enabled, position: position);

void main() {
  group('orderLyricsSources', () {
    List<String> ids(List<LyricsSourceEntry> e) => [for (final x in e) x.id];

    test('LRCLIB first, then plugins in install order, all on', () {
      final entries = orderLyricsSources([
        _record('plugin-aaaaaaaaaaaa', 10),
        _record('plugin-bbbbbbbbbbbb', 20),
      ], const []);
      expect(ids(entries), [
        'lrclib',
        'plugin-aaaaaaaaaaaa',
        'plugin-bbbbbbbbbbbb',
      ]);
      expect(entries.every((e) => e.enabled), isTrue);
      expect(entries.first.record, isNull);
      expect(entries.last.record, isNotNull);
    });

    test('saved positions and flags win; a plugin without a row goes last', () {
      final entries = orderLyricsSources(
        [
          _record('plugin-aaaaaaaaaaaa', 10),
          _record('plugin-bbbbbbbbbbbb', 20),
          _record('plugin-cccccccccccc', 30),
        ],
        [
          _pref('plugin-bbbbbbbbbbbb', 0),
          _pref('lrclib', 1, enabled: false),
          _pref('plugin-aaaaaaaaaaaa', 2),
        ],
      );
      expect(ids(entries), [
        'plugin-bbbbbbbbbbbb',
        'lrclib',
        'plugin-aaaaaaaaaaaa',
        'plugin-cccccccccccc',
      ]);
      expect(entries[1].enabled, isFalse);
      expect(entries[3].enabled, isTrue);
    });

    test('removed records and rows of unknown sources are not sources', () {
      final entries = orderLyricsSources(
        [_record('plugin-aaaaaaaaaaaa', 10, removed: true)],
        [_pref('plugin-aaaaaaaaaaaa', 0), _pref('plugin-zzzzzzzzzzzz', 1)],
      );
      expect(ids(entries), ['lrclib']);
    });
  });

  group('with a database', () {
    late PluginProviderEnv env;
    late ProviderContainer container;
    late LyricsPluginRecord first;
    late LyricsPluginRecord second;
    late List<LogRecord> appLog;

    /// Polls real time; the ten second limit is only a hang guard, the
    /// condition itself is the assertion.
    Future<void> until(bool Function() done) async {
      final end = DateTime.now().add(const Duration(seconds: 10));
      while (!done()) {
        if (DateTime.now().isAfter(end)) fail('condition not reached');
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    List<String> running() => [
      for (final r in container.read(lyricsProvidersProvider)) r.id,
    ];

    setUp(() async {
      env = await PluginProviderEnv.create();
      addTearDown(env.dispose);
      first = await env.install(name: 'First');
      second = await env.install(name: 'Second');
      appLog = [];
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord
          .where((r) => r.loggerName == 'lyrics_sources')
          .listen(appLog.add);
      addTearDown(sub.cancel);
      container = ProviderContainer(
        overrides: [
          libraryDatabaseProvider.overrideWithValue(env.db),
          lyricsPluginDataDirectoryProvider.overrideWithValue(
            env.store.dataDir.path,
          ),
          pluginRuntimeProvider.overrideWithValue(env.runtime),
          pluginRunRegistryProvider.overrideWithValue(env.store.runs),
          lyricsPluginsControllerProvider.overrideWithValue(env.controller),
        ],
      );
      addTearDown(container.dispose);
      container.listen(lyricsProvidersProvider, (_, _) {});
      container.listen(lyricsSourceNamesProvider, (_, _) {});
      container.listen(lyricsSourcesLoadedProvider, (_, _) {});
    });

    test('loaded only after both tables have answered', () async {
      expect(container.read(lyricsSourcesLoadedProvider), isFalse);
      // Until then nothing but LRCLIB is listed.
      expect(running(), ['lrclib']);

      await container.read(lyricsSourcesInputProvider.future);

      expect(container.read(lyricsSourcesLoadedProvider), isTrue);
      expect(running(), ['lrclib', first.installId, second.installId]);
    });

    test('order and enable flags drive the providers', () async {
      await container.read(lyricsSourcesInputProvider.future);

      await env.controller.setEnabled(first.installId, false);
      await until(() => running().length == 2);
      expect(running(), ['lrclib', second.installId]);

      await env.controller.reorder([second.installId, 'lrclib']);
      await until(() => running().first == second.installId);
      expect(running(), [second.installId, 'lrclib']);

      await env.controller.setEnabled(first.installId, true);
      await until(() => running().length == 3);
      expect(running().first, second.installId);
      expect(running(), contains(first.installId));
    });

    test('a plugin is registered with its name and hosts', () async {
      await container.read(lyricsSourcesInputProvider.future);
      final registration = container
          .read(lyricsProvidersProvider)
          .firstWhere((r) => r.id == first.installId);
      expect(registration.displayName, 'First');
      expect(registration.hosts, ['api.example.com']);
    });

    test('a plugin whose registration fails is skipped and logged', () async {
      await container.read(lyricsSourcesInputProvider.future);
      // A hand edit of the database that the list streams still notice.
      await env.db.customUpdate(
        'UPDATE lyrics_plugins SET hosts = ? WHERE install_id = ?',
        variables: [
          Variable<String>('["localhost"]'),
          Variable<String>(first.installId),
        ],
        updates: {env.db.lyricsPlugins},
        updateKind: UpdateKind.update,
      );
      await until(() => !running().contains(first.installId));

      expect(running(), ['lrclib', second.installId]);
      final line = appLog.firstWhere(
        (r) => r.message.contains(first.installId),
      );
      expect(line.level, Level.WARNING);
      expect(line.message, isNot(contains('First')));
    });

    test('names cover enabled sources and every record', () async {
      await container.read(lyricsSourcesInputProvider.future);
      await env.controller.setEnabled(first.installId, false);
      // The second plugin saved lyrics, so its record outlives an uninstall.
      await env.db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: 'k',
          providerId: second.installId,
          status: OnlineLyricsStatus.found.value,
          fetchedAt: 1,
        ),
      );
      await env.controller.uninstall(second.installId);
      await until(
        () =>
            container
                .read(lyricsSourceNamesProvider)[second.installId]
                ?.removed ==
            true,
      );

      final names = container.read(lyricsSourceNamesProvider);
      expect(names['lrclib']!.displayName, 'LRCLIB');
      expect(names[first.installId]!.displayName, 'First');
      expect(names[first.installId]!.removed, isFalse);
      expect(names[first.installId]!.author, 'someone');
      expect(names[second.installId]!.removed, isTrue);
      expect(running(), ['lrclib']);
    });
  });

  test('without a data folder the plugins are not registered', () async {
    final env = await PluginProviderEnv.create();
    addTearDown(env.dispose);
    final record = await env.install();
    final container = ProviderContainer(
      overrides: [libraryDatabaseProvider.overrideWithValue(env.db)],
    );
    addTearDown(container.dispose);
    container.listen(lyricsProvidersProvider, (_, _) {});
    await container.read(lyricsSourcesInputProvider.future);

    expect(container.read(lyricsProvidersProvider).map((r) => r.id), [
      'lrclib',
    ]);
    expect(
      container.read(lyricsSourceNamesProvider).containsKey(record.installId),
      isTrue,
    );
  });
}
