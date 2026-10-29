import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';

OnlineLyricsCompanion lyrics(
  String key,
  String provider, {
  String status = 'found',
  String? remoteId = 'r1',
  String? synced,
  String? plain,
}) => OnlineLyricsCompanion.insert(
  cacheKey: key,
  providerId: provider,
  status: status,
  remoteId: Value(remoteId),
  syncedText: Value(synced),
  plainText: Value(plain),
  fetchedAt: 1,
);

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('online lyrics rows', () {
    test('saving the same key and provider overwrites', () async {
      await db.saveOnlineLyrics(lyrics('k', 'lrclib', plain: 'old'));
      await db.saveOnlineLyrics(lyrics('k', 'lrclib', plain: 'new'));
      final rows = await db.watchOnlineLyrics('k').first;
      expect(rows.single.plainText, 'new');
    });

    test('two providers coexist; delete removes both', () async {
      await db.saveOnlineLyrics(lyrics('k', 'lrclib'));
      await db.saveOnlineLyrics(lyrics('k', 'other', status: 'not_found'));
      final rows = await db.watchOnlineLyrics('k').first;
      expect(rows.map((r) => r.providerId).toSet(), {'lrclib', 'other'});
      expect(
        rows.firstWhere((r) => r.providerId == 'other').lookupStatus,
        OnlineLyricsStatus.notFound,
      );
      await db.deleteOnlineLyrics('k');
      expect(await db.watchOnlineLyrics('k').first, isEmpty);
    });

    test('a row with an unknown status is skipped', () async {
      await db.saveOnlineLyrics(lyrics('k', 'lrclib'));
      await db.saveOnlineLyrics(lyrics('k', 'other', status: 'future'));
      final rows = await db.watchOnlineLyrics('k').first;
      expect(rows.single.providerId, 'lrclib');
    });
  });

  group('pins', () {
    test('a pick is replaced by a skip, then removed', () async {
      await db.pinLyrics(
        LyricsPinsCompanion.insert(
          trackKey: '/m/a.flac',
          pinnedAt: 1,
          providerId: const Value('lrclib'),
          remoteId: const Value('r1'),
          syncedText: const Value('[00:01.00]words'),
          plainText: const Value('words'),
          instrumental: const Value(true),
        ),
      );
      var pin = await db.watchLyricsPin('/m/a.flac').first;
      expect(pin?.remoteId, 'r1');
      expect(pin?.plainText, 'words');

      await db.pinLyrics(
        LyricsPinsCompanion.insert(trackKey: '/m/a.flac', pinnedAt: 2),
      );
      pin = await db.watchLyricsPin('/m/a.flac').first;
      expect(pin, isNotNull);
      expect(pin!.remoteId, isNull);
      expect(pin.providerId, isNull);
      expect(pin.plainText, isNull);
      expect(pin.syncedText, isNull);
      expect(pin.instrumental, isFalse);

      await db.removeLyricsPin('/m/a.flac');
      expect(await db.watchLyricsPin('/m/a.flac').first, isNull);
    });

    test('a pin survives closing and reopening the database file', () async {
      final dir = await Directory.systemTemp.createTemp('kanaru-pins');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/library.db');
      // The first connection is closed before the second opens.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final first = LibraryDatabase(NativeDatabase(file));
      await first.pinLyrics(
        LyricsPinsCompanion.insert(
          trackKey: '/m/a.flac',
          pinnedAt: 1,
          remoteId: const Value('r1'),
          syncedText: const Value('[00:01.00]hi'),
        ),
      );
      await first.close();

      final second = LibraryDatabase(NativeDatabase(file));
      addTearDown(second.close);
      final pin = await second.watchLyricsPin('/m/a.flac').first;
      expect(pin?.syncedText, '[00:01.00]hi');
    });
  });

  group('replace and distinct', () {
    test('rejecting resets a pick to a bare skip', () async {
      await db.pinLyrics(
        LyricsPinsCompanion.insert(
          trackKey: 't',
          pinnedAt: 1,
          providerId: const Value('lrclib'),
          remoteId: const Value('r1'),
          syncedText: const Value('[00:01.00]x'),
          instrumental: const Value(true),
        ),
      );
      await db.rejectOnlineLyrics(
        cacheKey: 'k',
        providerId: 'lrclib',
        remoteId: 'r1',
        trackKey: 't',
        now: 2,
      );
      final pin = (await db.watchLyricsPin('t').first)!;
      expect(pin.providerId, isNull);
      expect(pin.remoteId, isNull);
      expect(pin.syncedText, isNull);
      expect(pin.plainText, isNull);
      expect(pin.instrumental, isFalse);
    });

    test('saving not_found clears the old text and bytes', () async {
      await db.saveOnlineLyrics(
        lyrics('k', 'lrclib', synced: 'abcd', plain: 'ef'),
      );
      expect((await db.watchOnlineLyricsStats().first).bytes, 6);
      await db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: 'k',
          providerId: 'lrclib',
          status: 'not_found',
          fetchedAt: 2,
        ),
      );
      final row = (await db.watchOnlineLyrics('k').first).single;
      expect(row.remoteId, isNull);
      expect(row.syncedText, isNull);
      expect(row.plainText, isNull);
      expect(row.instrumental, isFalse);
      expect((await db.watchOnlineLyricsStats().first).bytes, 0);
    });

    test('pinning a bare skip over a pick drops its text', () async {
      await db.pinLyrics(
        LyricsPinsCompanion.insert(
          trackKey: 't',
          pinnedAt: 1,
          syncedText: const Value('x'),
        ),
      );
      await db.pinLyrics(
        LyricsPinsCompanion.insert(trackKey: 't', pinnedAt: 2),
      );
      expect((await db.watchLyricsPin('t').first)!.syncedText, isNull);
    });

    test('unrelated writes do not re-emit the pin or track streams', () async {
      final rootId = (await db.addRoots(['/m'], now: 1)).single;
      TracksCompanion row(String path) => TracksCompanion.insert(
        rootId: rootId,
        path: path,
        mtimeMs: 1,
        sizeBytes: 10,
        title: 'T',
        addedAt: 1,
        updatedAt: 1,
      );
      await db.upsertTracks([row('/m/a.flac')]);
      await db.pinLyrics(
        LyricsPinsCompanion.insert(trackKey: 't', pinnedAt: 1),
      );

      var fieldEmits = 0;
      var pinEmits = 0;
      final s1 = db
          .watchTrackLyricsFields('/m/a.flac')
          .listen((_) => fieldEmits++);
      final s2 = db.watchLyricsPin('t').listen((_) => pinEmits++);
      addTearDown(s1.cancel);
      addTearDown(s2.cancel);
      await pumpEventQueue();
      expect((fieldEmits, pinEmits), (1, 1));

      await db.upsertTracks([row('/m/b.flac')]);
      await db.pinLyrics(
        LyricsPinsCompanion.insert(trackKey: 'other', pinnedAt: 1),
      );
      await pumpEventQueue();
      expect((fieldEmits, pinEmits), (1, 1));
    });
  });

  group('reject', () {
    test('drops the rejected found row, keeps others, writes a skip', () async {
      await db.saveOnlineLyrics(lyrics('k', 'lrclib', remoteId: 'bad'));
      await db.saveOnlineLyrics(lyrics('k', 'other', remoteId: 'bad'));
      await db.rejectOnlineLyrics(
        cacheKey: 'k',
        providerId: 'lrclib',
        remoteId: 'bad',
        trackKey: '/m/a.flac',
        now: 5,
      );
      final rows = await db.watchOnlineLyrics('k').first;
      expect(rows.single.providerId, 'other');
      final pin = await db.watchLyricsPin('/m/a.flac').first;
      expect(pin, isNotNull);
      expect(pin!.remoteId, isNull);
      expect(await db.rejectedRemoteIds('k'), {('lrclib', 'bad')});
      expect(await db.rejectedRemoteIds('elsewhere'), isEmpty);
    });

    test('keeps a found row that has a different remote id', () async {
      await db.saveOnlineLyrics(lyrics('k', 'lrclib', remoteId: 'good'));
      await db.rejectOnlineLyrics(
        cacheKey: 'k',
        providerId: 'lrclib',
        remoteId: 'bad',
        trackKey: '/m/a.flac',
        now: 5,
      );
      expect((await db.watchOnlineLyrics('k').first).single.remoteId, 'good');
    });
  });

  group('stats and clear', () {
    test('counts rows and sums UTF-8 bytes of both tables', () async {
      await db.saveOnlineLyrics(
        lyrics('k', 'lrclib', synced: 'ab', plain: 'é'),
      );
      await db.saveOnlineLyrics(
        lyrics('k2', 'lrclib', status: 'not_found', remoteId: null),
      );
      await db.pinLyrics(
        LyricsPinsCompanion.insert(
          trackKey: 't',
          pinnedAt: 1,
          plainText: const Value('日本'),
          providerId: const Value('lrclib'),
          remoteId: const Value('r'),
        ),
      );
      await db.pinLyrics(
        LyricsPinsCompanion.insert(trackKey: 't2', pinnedAt: 1),
      );
      await db.rejectOnlineLyrics(
        cacheKey: 'k',
        providerId: 'lrclib',
        remoteId: 'r9',
        trackKey: 't3',
        now: 1,
      );
      final stats = await db.watchOnlineLyricsStats().first;
      expect(stats.found, 1);
      expect(stats.notFound, 1);
      expect(stats.picks, 1);
      // 't2' and the skip the rejection wrote for 't3'.
      expect(stats.skips, 2);
      expect(stats.rejects, 1);
      // 2 + 2 (é) + 6 (two CJK characters).
      expect(stats.bytes, 10);
    });

    test('clear empties all three tables and returns the row count', () async {
      await db.saveOnlineLyrics(lyrics('k', 'lrclib'));
      await db.pinLyrics(
        LyricsPinsCompanion.insert(trackKey: 't', pinnedAt: 1),
      );
      await db.rejectOnlineLyrics(
        cacheKey: 'k',
        providerId: 'lrclib',
        remoteId: 'r1',
        trackKey: 't2',
        now: 2,
      );
      // 0 found (rejected), 2 pins, 1 reject.
      expect(await db.clearOnlineLyrics(), 3);
      final stats = await db.watchOnlineLyricsStats().first;
      expect(
        (stats.found, stats.notFound, stats.picks, stats.skips, stats.rejects),
        (0, 0, 0, 0, 0),
      );
      expect(await db.rejectedRemoteIds('k'), isEmpty);
    });
  });

  group('track lyrics fields', () {
    test(
      'reads a library song, null for an unknown path, follows updates',
      () async {
        final rootId = (await db.addRoots(['/m'], now: 1)).single;
        TracksCompanion row(String title) => TracksCompanion.insert(
          rootId: rootId,
          path: '/m/a.flac',
          mtimeMs: 1,
          sizeBytes: 10,
          title: title,
          artist: const Value('Ann'),
          album: const Value('LP'),
          durationMs: const Value(200000),
          addedAt: 1,
          updatedAt: 1,
        );
        await db.upsertTracks([row('Old')]);

        expect(await db.watchTrackLyricsFields('/nope').first, isNull);

        final emitted = <String?>[];
        final sub = db
            .watchTrackLyricsFields('/m/a.flac')
            .listen((f) => emitted.add(f?.title));
        addTearDown(sub.cancel);
        await pumpEventQueue();
        expect(emitted, ['Old']);

        await db.upsertTracks([row('New')]);
        await pumpEventQueue();
        expect(emitted.last, 'New');
        final fields = await db.watchTrackLyricsFields('/m/a.flac').first;
        expect(fields?.artist, 'Ann');
        expect(fields?.album, 'LP');
        expect(fields?.durationMs, 200000);
      },
    );
  });
}
