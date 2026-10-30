import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';

import 'lyrics_plugin_test_helpers.dart';

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<(String, bool, int)>> prefs() async => [
    for (final p in await db.watchLyricsSourcePrefs().first)
      (p.providerId, p.enabled, p.position),
  ];

  group('source preferences', () {
    setUp(() async {
      await db.insertLyricsPlugin('plugin-a', pluginSpec(), now: 1);
      await db.insertLyricsPlugin(
        'plugin-b',
        pluginSpec(packageDir: 'b/v1-1'),
        now: 1,
      );
    });

    test('no rows at first; next position is 1', () async {
      expect(await prefs(), isEmpty);
      expect(await db.nextLyricsSourcePosition(), 1);
    });

    test('enabling puts a new source at the end', () async {
      await db.setLyricsSourceEnabled('plugin-a', true);
      await db.setLyricsSourceEnabled('plugin-b', false);
      expect(await prefs(), [('plugin-a', true, 1), ('plugin-b', false, 2)]);
      expect(await db.nextLyricsSourcePosition(), 3);
    });

    test('lrclib with no row is switched off at position 0', () async {
      await db.setLyricsSourceEnabled('plugin-a', true);
      await db.setLyricsSourceEnabled('lrclib', false);
      expect(await prefs(), [('lrclib', false, 0), ('plugin-a', true, 1)]);
    });

    test('toggling keeps the position', () async {
      await db.setLyricsSourceEnabled('plugin-a', true);
      await db.setLyricsSourceEnabled('plugin-b', true);
      await db.setLyricsSourceEnabled('plugin-a', false);
      expect(await prefs(), [('plugin-a', false, 1), ('plugin-b', true, 2)]);
    });

    test('reorder rewrites positions 0..n and keeps enabled', () async {
      await db.setLyricsSourceEnabled('plugin-a', false);
      await db.setLyricsSourceEnabled('plugin-b', true);
      await db.reorderLyricsSources(['plugin-b', 'lrclib', 'plugin-a']);
      expect(await prefs(), [
        ('plugin-b', true, 0),
        ('lrclib', true, 1),
        ('plugin-a', false, 2),
      ]);
    });

    test('reorder ignores a repeated id', () async {
      await db.reorderLyricsSources(['a', 'b', 'a', 'c']);
      expect(await prefs(), [
        ('a', true, 0),
        ('b', true, 1),
        ('c', true, 2),
        ('lrclib', true, 3),
      ]);
    });

    test('reorder keeps every other source after the given ones', () async {
      await db.setLyricsSourceEnabled('plugin-a', true);
      await db.setLyricsSourceEnabled('plugin-b', false);
      // lrclib has no row: it counts as first, so it ends up after plugin-b.
      final result = await db.reorderLyricsSources(['plugin-b']);
      expect(result.written, ['plugin-b']);
      expect(await prefs(), [
        ('plugin-b', false, 0),
        ('lrclib', true, 1),
        ('plugin-a', true, 2),
      ]);
    });

    test('reorder without lrclib never ties at position 0', () async {
      await db.reorderLyricsSources(['plugin-a', 'plugin-b']);
      expect(await prefs(), [
        ('plugin-a', true, 0),
        ('plugin-b', true, 1),
        ('lrclib', true, 2),
      ]);
    });

    test('a toggle after uninstall writes nothing', () async {
      await seedPluginReferences(db, 'plugin-a');
      await db.setLyricsSourceEnabled('plugin-a', true);
      await db.uninstallLyricsPlugin('plugin-a', now: 5);
      expect(
        await db.setLyricsSourceEnabled('plugin-a', false),
        LyricsPluginWrite.skipped,
      );
      expect(await prefs(), isEmpty);
      // Unknown plugins too; lrclib is always allowed.
      expect(
        await db.setLyricsSourceEnabled('plugin-z', true),
        LyricsPluginWrite.skipped,
      );
      expect(
        await db.setLyricsSourceEnabled('lrclib', false),
        LyricsPluginWrite.written,
      );
    });

    test('a reorder after uninstall skips the removed plugin', () async {
      await seedPluginReferences(db, 'plugin-a');
      await db.uninstallLyricsPlugin('plugin-a', now: 5);
      final result = await db.reorderLyricsSources(['plugin-a', 'plugin-b']);
      expect(result.skipped, ['plugin-a']);
      expect(result.written, ['plugin-b']);
      expect((await prefs()).map((p) => p.$1), ['plugin-b', 'lrclib']);
    });

    test('a stale preference does not come back on revive', () async {
      await seedPluginReferences(db, 'plugin-a');
      await db.uninstallLyricsPlugin('plugin-a', now: 5);
      await db.setLyricsSourceEnabled('plugin-a', false);
      await db.reorderLyricsSources(['plugin-a']);
      await db.reviveLyricsPlugin('plugin-a', pluginSpec(), now: 6);
      expect((await prefs()).any((p) => p.$1 == 'plugin-a'), isFalse);
    });

    test('reorder is one transaction', () async {
      await db.setLyricsSourceEnabled('plugin-a', true);
      await db.customStatement(
        'CREATE TRIGGER block_pref BEFORE INSERT ON lyrics_source_prefs '
        "WHEN NEW.provider_id = 'bad' BEGIN SELECT RAISE(ABORT, 'boom'); END",
      );
      await expectLater(
        db.reorderLyricsSources(['plugin-a', 'x', 'bad']),
        throwsA(isA<Exception>()),
      );
      expect(await prefs(), [('plugin-a', true, 1)]);
    });
  });

  group('repositories', () {
    test('add, watch and remove', () async {
      expect(
        await db.addLyricsPluginRepo('https://r/1', name: 'One', now: 1),
        isTrue,
      );
      expect(
        await db.addLyricsPluginRepo('https://r/1', name: 'Dup', now: 2),
        isFalse,
      );
      await db.addLyricsPluginRepo(
        'https://r/2',
        name: 'Two',
        author: 'me',
        now: 3,
      );
      final repos = await db.watchLyricsPluginRepos().first;
      expect(repos.map((r) => r.name), ['One', 'Two']);
      expect(repos.last.author, 'me');
      expect(repos.first.catalog, isNull);

      expect(await db.removeLyricsPluginRepo('https://r/1'), isTrue);
      expect(await db.removeLyricsPluginRepo('https://r/1'), isFalse);
      expect(
        (await db.watchLyricsPluginRepos().first).single.url,
        'https://r/2',
      );
    });

    test('a good fetch stores the catalog, a failure keeps it', () async {
      await db.addLyricsPluginRepo('https://r/1', name: 'One', now: 1);
      expect(
        await db.saveLyricsPluginRepoFetch(
          'https://r/1',
          catalog: '{"plugins":[]}',
          now: 10,
        ),
        LyricsPluginWrite.written,
      );
      expect(
        await db.saveLyricsPluginRepoFetch(
          'https://r/1',
          error: 'network',
          now: 20,
        ),
        LyricsPluginWrite.written,
      );
      var repo = (await db.watchLyricsPluginRepos().first).single;
      expect(repo.catalog, '{"plugins":[]}');
      expect(repo.lastFetchedAt, 10);
      expect(repo.lastError, 'network');

      await db.saveLyricsPluginRepoFetch(
        'https://r/1',
        catalog: '{"plugins":[1]}',
        now: 30,
      );
      repo = (await db.watchLyricsPluginRepos().first).single;
      expect(repo.lastError, isNull);
      expect(repo.lastFetchedAt, 30);
    });

    test('catalog over 1 MiB, unknown url and bad arguments', () async {
      await db.addLyricsPluginRepo('https://r/1', name: 'One', now: 1);
      expect(
        await db.saveLyricsPluginRepoFetch(
          'https://r/1',
          catalog: 'x' * (lyricsPluginCatalogMaxBytes + 1),
          now: 2,
        ),
        LyricsPluginWrite.tooLarge,
      );
      expect((await db.watchLyricsPluginRepos().first).single.catalog, isNull);
      expect(
        await db.saveLyricsPluginRepoFetch('https://nope', error: 'x', now: 2),
        LyricsPluginWrite.skipped,
      );
      expect(
        () => db.saveLyricsPluginRepoFetch('https://r/1', now: 2),
        throwsArgumentError,
      );
      expect(
        () => db.saveLyricsPluginRepoFetch(
          'https://r/1',
          catalog: '{}',
          error: 'x',
          now: 2,
        ),
        throwsArgumentError,
      );
    });
  });

  group('data stats and per-source clear', () {
    setUp(() async {
      await db.insertLyricsPlugin('plugin-a', pluginSpec(), now: 1);
      await db.insertLyricsPlugin(
        'plugin-b',
        pluginSpec(packageDir: 'b/v1-1'),
        now: 1,
      );
    });

    test('zero for a plugin with nothing', () async {
      final s = await db.lyricsPluginDataStats('plugin-a');
      expect((s.storageBytes, s.foundCount, s.textBytes), (2, 0, 0));
      final none = await db.lyricsPluginDataStats('plugin-z');
      expect((none.storageBytes, none.foundCount, none.textBytes), (0, 0, 0));
    });

    test('counts storage and the plugin own found rows', () async {
      await db.setLyricsPluginStorage('plugin-a', {
        'k': 'é',
      }, expectedUpdatedAt: 1);
      await db.saveOnlineLyrics(lyricsRow('k1', 'plugin-a', plain: 'héllo'));
      await db.saveOnlineLyrics(lyricsRow('k2', 'plugin-a', plain: 'ab'));
      await db.saveOnlineLyrics(
        lyricsRow('k3', 'plugin-a', status: 'not_found', plain: null),
      );
      await db.saveOnlineLyrics(lyricsRow('k1', 'plugin-b', plain: 'other'));
      final s = await db.lyricsPluginDataStats('plugin-a');
      expect(s.storageBytes, '{"k":"é"}'.length + 1);
      expect(s.foundCount, 2);
      expect(s.textBytes, 6 + 2);
    });

    test('clearing a source keeps pins, rejects and other sources', () async {
      await seedPluginReferences(db, 'plugin-a', pin: true, reject: true);
      await seedPluginReferences(db, 'plugin-b');
      final removed = await db.clearLyricsPluginSavedLyrics('plugin-a');
      expect(removed, 2);
      expect(await countRows(db, 'online_lyrics'), 2);
      expect(await countRows(db, 'lyrics_pins'), 1);
      expect(await countRows(db, 'online_lyrics_rejects'), 1);
      expect(await db.lyricsPluginById('plugin-a'), isNotNull);
    });
  });
}
