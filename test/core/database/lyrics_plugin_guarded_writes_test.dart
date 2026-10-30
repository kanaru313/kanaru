import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';

import 'lyrics_plugin_test_helpers.dart';

void main() {
  late LibraryDatabase db;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    await db.insertLyricsPlugin('plugin-a', pluginSpec(), now: 100);
  });
  tearDown(() => db.close());

  group('storage', () {
    test('writes when the record is live and updated_at matches', () async {
      final result = await db.setLyricsPluginStorage('plugin-a', {
        'a': 1,
      }, expectedUpdatedAt: 100);
      expect(result, LyricsPluginWrite.written);
      expect((await db.lyricsPluginDataFor('plugin-a'))!.storage, '{"a":1}');
    });

    test('a stale updated_at writes nothing', () async {
      final result = await db.setLyricsPluginStorage('plugin-a', {
        'a': 1,
      }, expectedUpdatedAt: 99);
      expect(result, LyricsPluginWrite.skipped);
      expect((await db.lyricsPluginDataFor('plugin-a'))!.storage, '{}');
    });

    test('after a package switch the old run writes nothing', () async {
      await db.switchLyricsPluginPackage('plugin-a', pluginSpec(), now: 200);
      expect(
        await db.setLyricsPluginStorage('plugin-a', {
          'a': 1,
        }, expectedUpdatedAt: 100),
        LyricsPluginWrite.skipped,
      );
      expect((await db.lyricsPluginDataFor('plugin-a'))!.storage, '{}');
    });

    test('after an uninstall nothing is written or created', () async {
      await db.uninstallLyricsPlugin('plugin-a', now: 150);
      expect(
        await db.setLyricsPluginStorage('plugin-a', {
          'a': 1,
        }, expectedUpdatedAt: 100),
        LyricsPluginWrite.skipped,
      );
      expect(await countRows(db, 'lyrics_plugin_data'), 0);
    });

    test('after an uninstall that left a removed record', () async {
      await seedPluginReferences(db, 'plugin-a');
      await db.uninstallLyricsPlugin('plugin-a', now: 150);
      expect(
        await db.setLyricsPluginStorage('plugin-a', {
          'a': 1,
        }, expectedUpdatedAt: 100),
        LyricsPluginWrite.skipped,
      );
      expect(await countRows(db, 'lyrics_plugin_data'), 0);
    });

    test('an unknown plugin writes nothing', () async {
      expect(
        await db.setLyricsPluginStorage('plugin-z', {
          'a': 1,
        }, expectedUpdatedAt: 100),
        LyricsPluginWrite.skipped,
      );
      expect(await countRows(db, 'lyrics_plugin_data'), 1);
    });

    test('over 64 KiB is rejected, exactly at the cap is kept', () async {
      // {"k":"..."} adds 8 bytes around the value.
      final atCap = {'k': 'x' * (lyricsPluginDataMaxBytes - 8)};
      expect(
        await db.setLyricsPluginStorage(
          'plugin-a',
          atCap,
          expectedUpdatedAt: 100,
        ),
        LyricsPluginWrite.written,
      );
      final over = {'k': 'x' * (lyricsPluginDataMaxBytes - 7)};
      expect(
        await db.setLyricsPluginStorage(
          'plugin-a',
          over,
          expectedUpdatedAt: 100,
        ),
        LyricsPluginWrite.tooLarge,
      );
      expect(
        (await db.lyricsPluginDataFor('plugin-a'))!.storage.length,
        lyricsPluginDataMaxBytes,
      );
    });

    test('the size cap counts UTF-8 bytes, not characters', () async {
      final wide = {'k': 'é' * (lyricsPluginDataMaxBytes ~/ 2)};
      expect(
        await db.setLyricsPluginStorage(
          'plugin-a',
          wide,
          expectedUpdatedAt: 100,
        ),
        LyricsPluginWrite.tooLarge,
      );
    });

    test(
      'does not touch config values and stays out of record streams',
      () async {
        await db.setLyricsPluginConfigValues('plugin-a', {'c': 1});
        var emissions = 0;
        final sub = db.watchLyricsPluginRecords().listen((_) => emissions++);
        await pumpEventQueue();
        final before = emissions;
        await db.setLyricsPluginStorage('plugin-a', {
          's': 1,
        }, expectedUpdatedAt: 100);
        await db.setLyricsPluginConfigValues('plugin-a', {'c': 2});
        await pumpEventQueue();
        await sub.cancel();
        expect(emissions, before);
        final data = (await db.lyricsPluginDataFor('plugin-a'))!;
        expect(data.storage, '{"s":1}');
        expect(data.configValues, '{"c":2}');
      },
    );
  });

  group('config values', () {
    test('a removed plugin takes no config', () async {
      await seedPluginReferences(db, 'plugin-a');
      await db.uninstallLyricsPlugin('plugin-a', now: 150);
      expect(
        await db.setLyricsPluginConfigValues('plugin-a', {'a': 1}),
        LyricsPluginWrite.skipped,
      );
    });

    test('over 64 KiB is rejected', () async {
      expect(
        await db.setLyricsPluginConfigValues('plugin-a', {
          'k': 'x' * lyricsPluginDataMaxBytes,
        }),
        LyricsPluginWrite.tooLarge,
      );
    });
  });

  group('saving plugin lyrics', () {
    test('saves while the plugin is live', () async {
      expect(
        await db.saveOnlineLyrics(lyricsRow('k', 'plugin-a', plain: 'one')),
        isTrue,
      );
      expect(
        await db.saveOnlineLyrics(lyricsRow('k', 'plugin-a', plain: 'two')),
        isTrue,
      );
      final rows = await db.watchOnlineLyrics('k').first;
      expect(rows.single.plainText, 'two');
      expect(rows.single.remoteId, 'r1');
      expect(rows.single.instrumental, isFalse);
    });

    test('keeps every column of the companion', () async {
      await db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: 'k',
          providerId: 'plugin-a',
          status: 'found',
          remoteId: const Value('r9'),
          syncedText: const Value('[00:01.00]hi'),
          instrumental: const Value(true),
          remoteDurationMs: const Value(1234),
          fetchedAt: 77,
        ),
      );
      final row = (await db.watchOnlineLyrics('k').first).single;
      expect(
        (
          row.remoteId,
          row.syncedText,
          row.plainText,
          row.instrumental,
          row.remoteDurationMs,
          row.fetchedAt,
        ),
        ('r9', '[00:01.00]hi', null, true, 1234, 77),
      );
    });

    test('a late save after uninstall leaves no row', () async {
      await db.uninstallLyricsPlugin('plugin-a', now: 150);
      expect(await db.saveOnlineLyrics(lyricsRow('k', 'plugin-a')), isFalse);
      expect(await countRows(db, 'online_lyrics'), 0);
    });

    test('a late save for a removed record leaves no row', () async {
      await seedPluginReferences(db, 'plugin-a', notFound: false);
      await db.uninstallLyricsPlugin('plugin-a', now: 150);
      expect(await db.saveOnlineLyrics(lyricsRow('k2', 'plugin-a')), isFalse);
      expect(await countRows(db, 'online_lyrics'), 1);
    });

    test('an unknown plugin id saves nothing', () async {
      expect(await db.saveOnlineLyrics(lyricsRow('k', 'plugin-z')), isFalse);
      expect(await countRows(db, 'online_lyrics'), 0);
    });

    test('lrclib rows need no record', () async {
      expect(await db.saveOnlineLyrics(lyricsRow('k', 'lrclib')), isTrue);
      expect(await countRows(db, 'online_lyrics'), 1);
    });

    test('a save notifies the lyrics stream', () async {
      final seen = <int>[];
      final sub = db.watchOnlineLyrics('k').listen((r) => seen.add(r.length));
      await pumpEventQueue();
      await db.saveOnlineLyrics(lyricsRow('k', 'plugin-a'));
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.last, 1);
    });
  });
}
