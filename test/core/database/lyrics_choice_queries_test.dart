import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';

OnlineLyricsCompanion cached(
  String key,
  String remoteId, {
  String provider = 'lrclib',
  String? synced,
  String? plain,
}) => OnlineLyricsCompanion.insert(
  cacheKey: key,
  providerId: provider,
  status: 'found',
  remoteId: Value(remoteId),
  syncedText: Value(synced),
  plainText: Value(plain),
  fetchedAt: 1,
);

LyricsPinsCompanion pin(
  String trackKey,
  String remoteId, {
  String? mode,
  String? plain,
}) => LyricsPinsCompanion.insert(
  trackKey: trackKey,
  pinnedAt: 1,
  mode: Value(mode),
  providerId: const Value('lrclib'),
  remoteId: Value(remoteId),
  plainText: Value(plain),
);

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<LyricsPinRow?> pinOf(String trackKey) =>
      db.watchLyricsPin(trackKey).first;

  Future<void> reject(
    String remoteId, {
    String? hash,
    Set<String> duplicates = const {},
  }) => db.rejectOnlineLyrics(
    cacheKey: 'k',
    providerId: 'lrclib',
    remoteId: remoteId,
    contentHash: hash,
    duplicateRemoteIds: duplicates,
    trackKey: 't',
    now: 9,
  );

  group('lyrics choice', () {
    test('keeps the pick columns and round-trips local, off, online', () async {
      await db.pinLyrics(pin('t', 'r1', mode: 'online', plain: 'words'));
      for (final mode in ['local', 'off', 'online']) {
        await db.setLyricsChoice('t', mode, 5);
        final row = (await pinOf('t'))!;
        expect(row.mode, mode);
        expect(row.remoteId, 'r1');
        expect(row.plainText, 'words');
        expect(row.pinnedAt, 5);
      }
    });

    test('creates a pin row without a pick', () async {
      await db.setLyricsChoice('t', 'off', 3);
      final row = (await pinOf('t'))!;
      expect((row.mode, row.remoteId, row.providerId), ('off', null, null));
    });

    test('removing the pin goes back to auto', () async {
      await db.setLyricsChoice('t', 'local', 3);
      await db.removeLyricsPin('t');
      expect(await pinOf('t'), isNull);
    });
  });

  group('pick', () {
    test(
      'stores mode online and drops rejects by id and hash of its key',
      () async {
        await db.rejectOnlineLyrics(
          cacheKey: 'k',
          providerId: 'lrclib',
          remoteId: 'same-id',
          contentHash: 'h1',
          trackKey: 'x',
          now: 1,
        );
        await db.rejectOnlineLyrics(
          cacheKey: 'k',
          providerId: 'lrclib',
          remoteId: 'other-id',
          contentHash: 'h2',
          trackKey: 'x',
          now: 1,
        );
        await db.rejectOnlineLyrics(
          cacheKey: 'k',
          providerId: 'lrclib',
          remoteId: 'unrelated',
          contentHash: 'h3',
          trackKey: 'x',
          now: 1,
        );
        await db.rejectOnlineLyrics(
          cacheKey: 'elsewhere',
          providerId: 'lrclib',
          remoteId: 'x1',
          contentHash: 'h2',
          trackKey: 'x',
          now: 1,
        );
        await db.pickOnlineLyrics(
          pin('t', 'same-id'),
          cacheKey: 'k',
          providerId: 'lrclib',
          remoteId: 'same-id',
          contentHash: 'h2',
        );
        expect((await pinOf('t'))!.mode, 'online');
        expect((await db.rejectedMatches('k')).ids, {('lrclib', 'unrelated')});
        expect((await db.rejectedMatches('k')).hashes, {'h3'});
        expect((await db.rejectedMatches('elsewhere')).ids, {('lrclib', 'x1')});
      },
    );

    test('without a hash only the id reject goes', () async {
      await reject('a', hash: 'h');
      await reject('b', hash: 'h');
      await db.pickOnlineLyrics(
        pin('t', 'a'),
        cacheKey: 'k',
        providerId: 'lrclib',
        remoteId: 'a',
      );
      expect((await db.rejectedMatches('k')).ids, {('lrclib', 'b')});
    });
  });

  group('reject', () {
    test('on an auto match drops the row and its duplicates, no pin', () async {
      await db.saveOnlineLyrics(cached('k', 'bad'));
      await db.saveOnlineLyrics(cached('k', 'dup', provider: 'other'));
      await db.saveOnlineLyrics(cached('k', 'keep', provider: 'third'));
      await db.saveOnlineLyrics(cached('elsewhere', 'bad'));
      await reject('bad', hash: 'h', duplicates: {'dup'});

      final rows = await db.watchOnlineLyrics('k').first;
      expect(rows.map((r) => r.remoteId), ['keep']);
      expect((await db.watchOnlineLyrics('elsewhere').first), hasLength(1));
      expect(await pinOf('t'), isNull);
      final matches = await db.rejectedMatches('k');
      expect(matches.ids, {('lrclib', 'bad')});
      expect(matches.hashes, {'h'});
    });

    test('on a pick with mode online deletes the row', () async {
      await db.pinLyrics(pin('t', 'bad', mode: 'online', plain: 'w'));
      await reject('bad');
      expect(await pinOf('t'), isNull);
    });

    test('on a pick without a mode deletes the row', () async {
      await db.pinLyrics(pin('t', 'bad', plain: 'w'));
      await reject('bad');
      expect(await pinOf('t'), isNull);
    });

    test('on mode local keeping another pick leaves row and pick', () async {
      await db.pinLyrics(pin('t', 'kept', mode: 'local', plain: 'w'));
      await reject('bad');
      final row = (await pinOf('t'))!;
      expect((row.mode, row.remoteId, row.plainText), ('local', 'kept', 'w'));
    });

    test(
      'on mode off holding the rejected pick keeps the choice only',
      () async {
        await db.pinLyrics(pin('t', 'bad', mode: 'off', plain: 'w'));
        await reject('bad');
        final row = (await pinOf('t'))!;
        expect(row.mode, 'off');
        expect(
          (row.providerId, row.remoteId, row.plainText),
          (null, null, null),
        );
      },
    );

    test('a pick of another record is untouched', () async {
      await db.pinLyrics(pin('t', 'kept', mode: 'online', plain: 'w'));
      await reject('bad');
      expect((await pinOf('t'))!.remoteId, 'kept');
    });
  });

  group('rejected matches', () {
    test('returns ids and only the non-null hashes', () async {
      await reject('a', hash: 'h');
      await reject('b');
      final matches = await db.rejectedMatches('k');
      expect(matches.ids, {('lrclib', 'a'), ('lrclib', 'b')});
      expect(matches.hashes, {'h'});
    });
  });

  group('stored text', () {
    Future<
      ({
        String? synced,
        String? plain,
        bool instrumental,
        int? remoteDurationMs,
      })?
    >
    stored(String remoteId, [String provider = 'lrclib']) =>
        db.storedOnlineLyricsText(
          trackKey: 't',
          cacheKey: 'k',
          providerId: provider,
          remoteId: remoteId,
        );

    test('prefers the matching pin, then the cache row, else null', () async {
      await db.saveOnlineLyrics(cached('k', 'r1', plain: 'cache'));
      await db.saveOnlineLyrics(
        cached('k', 'r2', provider: 'other', plain: 'second'),
      );
      expect((await stored('r1'))!.plain, 'cache');

      await db.pinLyrics(pin('t', 'r1', mode: 'online', plain: 'pinned'));
      expect((await stored('r1'))!.plain, 'pinned');
      // The pin holds another record: the cache row answers.
      expect((await stored('r2', 'other'))!.plain, 'second');
      expect(await stored('nope'), isNull);
    });

    test('ignores a not_found row', () async {
      await db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: 'k',
          providerId: 'lrclib',
          status: 'not_found',
          fetchedAt: 1,
        ),
      );
      expect(await stored('r1'), isNull);
    });
  });

  group('stats', () {
    test('count a pick once and a choice without a pick once', () async {
      await db.pinLyrics(pin('a', 'r1', mode: 'local', plain: 'é'));
      await db.pinLyrics(pin('b', 'r2', mode: 'online', plain: '日本'));
      await db.setLyricsChoice('c', 'off', 1);
      await db.setLyricsChoice('d', 'local', 1);
      await db.setLyricsChoice('e', 'future-mode', 1);
      final stats = await db.watchOnlineLyricsStats().first;
      expect(stats.picks, 2);
      expect(stats.choices, 2);
      // 2 (é) + 6 (two CJK characters).
      expect(stats.bytes, 8);
    });
  });
}
