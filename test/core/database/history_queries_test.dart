import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/history_queries.dart';
import 'package:kanaru/core/database/library_database.dart';

const _hour = 3600 * 1000;
const _day = 24 * _hour;

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> track(String path) async {
    await db.addRoots(['/m'], now: 1);
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            rootId: (await db.select(db.libraryRoots).getSingle()).id,
            path: path,
            mtimeMs: 1,
            sizeBytes: 1,
            title: 'T $path',
            artist: const Value('A'),
            addedAt: 1,
            updatedAt: 1,
          ),
        );
  }

  Future<int> play(String path, int at, {int? id}) => db
      .into(db.plays)
      .insert(
        PlaysCompanion.insert(
          id: Value.absentIfNull(id),
          path: path,
          playedAt: at,
        ),
      );

  group('buckets', () {
    test(
      'day edges land in the right day, empty days drop, newest first',
      () async {
        await play('/a', 999); // day 0 last ms
        await play('/a', 1000); // day 1 first ms
        await play('/a', 1000 + _day - 1); // day 1 last ms
        await play('/a', 1000 + 3 * _day); // day 4, day 2 and 3 empty
        final counts = await db.historyDayCounts([
          0,
          1000,
          1000 + _day,
          1000 + 2 * _day,
          1000 + 3 * _day,
          1000 + 4 * _day,
        ]);
        expect(counts.map((c) => (c.dayStart, c.count)), [
          (1000 + 3 * _day, 1),
          (1000, 2),
          (0, 1),
        ]);
      },
    );

    test('uneven buckets (23 h and 25 h days) count their own plays', () async {
      await play('/a', 23 * _hour - 1);
      await play('/a', 23 * _hour);
      await play('/a', 48 * _hour - 1);
      final counts = await db.historyDayCounts([0, 23 * _hour, 48 * _hour]);
      expect(counts.map((c) => (c.dayStart, c.count)), [
        (23 * _hour, 2),
        (0, 1),
      ]);
    });

    test('fewer than two bounds give nothing', () async {
      await play('/a', 5);
      expect(await db.historyDayCounts(const []), isEmpty);
      expect(await db.historyDayCounts([0]), isEmpty);
    });

    test('years with plays, newest first, range and empty history', () async {
      expect(await db.historyPlayedRange(), isNull);
      int ms(int y, int m, int d, [int h = 0]) =>
          DateTime(y, m, d, h).millisecondsSinceEpoch;
      await play('/a', ms(2021, 12, 31, 23));
      await play('/a', ms(2022, 1, 1));
      await play('/a', ms(2024, 6, 1));
      expect(await db.historyYears(2020, 2025), [2024, 2022, 2021]);
      expect(await db.historyYears(2022, 2022), [2022]);
      expect(await db.historyYears(2025, 2020), isEmpty);
      expect(await db.historyPlayedRange(), (
        first: ms(2021, 12, 31, 23),
        last: ms(2024, 6, 1),
      ));
    });
  });

  group('historyDayPlays', () {
    test(
      'order, nth across days, equal played_at by id, missing track',
      () async {
        await track('/a');
        final a1 = await play('/a', 100);
        await play('/gone', 150);
        final a2 = await play('/a', 5000);
        final a3 = await play('/a', 5000); // same played_at as a2, larger id
        final a4 = await play('/a', 9000);

        final day2 = await db.historyDayPlays(4000, 10000);
        expect(day2.map((r) => r.id), [a4, a3, a2]);
        expect(day2.map((r) => r.nth), [4, 3, 2]);
        expect(day2.first.track?.title, 'T /a');

        final day1 = await db.historyDayPlays(0, 4000);
        expect(day1.map((r) => (r.path, r.nth)), [('/gone', 1), ('/a', 1)]);
        expect(day1.last.id, a1);
        expect(day1.first.track, isNull);
      },
    );

    test('nth stays right after a delete', () async {
      final a = await play('/a', 1);
      final b = await play('/a', 2);
      final c = await play('/a', 3);
      await db.delete(db.plays).delete(PlaysCompanion(id: Value(a)));
      final rows = await db.historyDayPlays(0, 10);
      expect(rows.map((r) => (r.id, r.nth)), [(c, 2), (b, 1)]);
    });

    test('half-open range', () async {
      await play('/a', 10);
      await play('/a', 20);
      expect((await db.historyDayPlays(10, 20)).map((r) => r.playedAt), [10]);
    });
  });

  group('historyTopPlays', () {
    test(
      'ties go to the earlier last play, then path; limit; track null',
      () async {
        await track('/b');
        await play('/b', 10);
        await play('/b', 20);
        await play('/a', 15);
        await play('/a', 30);
        await play('/c', 40);
        await play('/c', 30); // same last as /a, but path sorts after
        await play('/z', 1);
        final rows = await db.historyTopPlays(start: 0, end: 100, limit: 3);
        expect(rows.map((r) => (r.path, r.count, r.lastPlayedAt)), [
          ('/b', 2, 20),
          ('/a', 2, 30),
          ('/c', 2, 40),
        ]);
        expect(rows.first.track?.title, 'T /b');
        expect(rows.last.track, isNull);
      },
    );

    test('range excludes plays outside [start, end)', () async {
      await play('/a', 9);
      await play('/a', 10);
      await play('/a', 19);
      await play('/a', 20);
      await play('/b', 30);
      final rows = await db.historyTopPlays(start: 10, end: 20, limit: 10);
      expect(rows.single.path, '/a');
      expect(rows.single.count, 2);
      expect(rows.single.lastPlayedAt, 19);
    });

    test('all time reads play_stats and matches a GROUP BY', () async {
      for (var i = 0; i < 5; i++) {
        await play('/p${i % 3}', 100 - i);
      }
      await play('/q', 7);
      final all = await db.historyTopPlays(limit: 10);
      final ranged = await db.historyTopPlays(start: 0, end: 1000, limit: 10);
      expect(
        all.map((r) => (r.path, r.count, r.lastPlayedAt)),
        ranged.map((r) => (r.path, r.count, r.lastPlayedAt)),
      );
      expect(all.length, 4);
    });

    test('start and end must come together', () {
      expect(() => db.historyTopPlays(start: 1, limit: 1), throwsArgumentError);
      expect(() => db.historyTopPlays(end: 1, limit: 1), throwsArgumentError);
    });
  });

  group('track history', () {
    test('summary and plays of a played track', () async {
      await track('/a');
      final first = await play('/a', 10);
      await play('/a', 30);
      await play('/a', 20);
      final summary = await db.historyTrackSummary('/a');
      expect(summary.count, 3);
      expect(summary.firstPlayedAt, 10);
      expect(summary.lastPlayedAt, 30);
      expect(summary.track?.title, 'T /a');
      final rows = await db.historyTrackPlays('/a');
      expect(rows.map((r) => r.playedAt), [30, 20, 10]);
      expect(rows.map((r) => r.nth), [3, 2, 1]);
      expect(rows.last.id, first);
      expect(rows.first.track, isNull);
    });

    test('a track with no play, in the library or not', () async {
      await track('/a');
      final inLib = await db.historyTrackSummary('/a');
      expect(inLib.count, 0);
      expect(inLib.firstPlayedAt, isNull);
      expect(inLib.lastPlayedAt, isNull);
      expect(inLib.track, isNotNull);
      final unknown = await db.historyTrackSummary('/nope');
      expect(unknown.count, 0);
      expect(unknown.track, isNull);
      expect(await db.historyTrackPlays('/nope'), isEmpty);
    });
  });

  group('distinct songs and totals', () {
    Future<void> trackWithCover(String path, String? cover) async {
      if ((await db.select(db.libraryRoots).get()).isEmpty) {
        await db.addRoots(['/m'], now: 1);
      }
      await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              rootId: (await db.select(db.libraryRoots).getSingle()).id,
              path: path,
              mtimeMs: 1,
              sizeBytes: 1,
              title: 'T $path',
              artist: const Value('A'),
              coverKey: Value(cover),
              addedAt: 1,
              updatedAt: 1,
            ),
          );
    }

    test('a day with A, B, A has 3 plays and 2 songs', () async {
      await play('/a', 10);
      await play('/b', 20);
      await play('/a', 30);
      await play('/a', 1000 + 5);
      final counts = await db.historyDayCounts([0, 1000, 2000]);
      expect(counts.map((c) => (c.dayStart, c.count, c.tracks)), [
        (1000, 1, 1),
        (0, 3, 2),
      ]);
    });

    test('uneven days keep distinct right', () async {
      await play('/a', 23 * _hour - 1);
      await play('/b', 23 * _hour);
      await play('/b', 24 * _hour);
      final counts = await db.historyDayCounts([0, 23 * _hour, 48 * _hour]);
      expect(counts.map((c) => (c.count, c.tracks)), [(2, 1), (1, 1)]);
    });

    test('range summary counts plays and songs in a half-open range', () async {
      await play('/a', 10);
      await play('/a', 20);
      await play('/b', 30);
      await play('/c', 40);
      expect(await db.historyRangeSummary(10, 40), (plays: 3, tracks: 2));
      expect(await db.historyRangeSummary(100, 200), (plays: 0, tracks: 0));
    });

    test(
      'overview: totals, first play, distinct covers newest first',
      () async {
        await trackWithCover('/a', 'k1');
        await trackWithCover('/b', 'k2');
        await trackWithCover('/c', null);
        await trackWithCover('/d', 'k1');
        await play('/a', 10);
        await play('/b', 20);
        await play('/c', 30);
        await play('/d', 40);
        await play('/b', 50);
        await play('/gone', 60); // not in the library: no cover
        final o = await db.historyOverview();
        expect(o.plays, 6);
        expect(o.tracks, 5);
        expect(o.firstPlayedAt, 10);
        expect(o.coverKeys, ['k2', 'k1']);
      },
    );

    test('overview of an empty history', () async {
      final o = await db.historyOverview();
      expect((o.plays, o.tracks, o.firstPlayedAt), (0, 0, null));
      expect(o.coverKeys, isEmpty);
    });

    test('played tracks: library songs only, last played first', () async {
      await trackWithCover('/a', null);
      await trackWithCover('/b', null);
      await trackWithCover('/never', null);
      await play('/a', 10);
      await play('/b', 20);
      await play('/a', 30);
      await play('/gone', 40);
      final list = await db.historyPlayedTracks();
      expect(list.map((t) => t.path), ['/a', '/b']);
    });
  });

  group('historyPlaysMatching', () {
    Future<void> titled(
      String path,
      String title, {
      String? artist,
      String? album,
    }) async {
      final root =
          (await db.select(db.libraryRoots).getSingleOrNull())?.id ??
          (await db.addRoots(['/m'], now: 1)).single;
      await db.upsertTracks([
        TracksCompanion.insert(
          rootId: root,
          path: path,
          mtimeMs: 1,
          sizeBytes: 10,
          title: title,
          artist: Value(artist),
          album: Value(album),
          addedAt: 100,
          updatedAt: 100,
        ),
      ]);
    }

    test('word prefixes of title, artist or album, accents ignored', () async {
      await titled('/a', 'Lạ Lùng', artist: 'Vũ');
      await titled('/b', 'Other', artist: 'Lalala Band');
      await titled('/c', 'Third', album: 'The Lal Album');
      await titled('/d', 'Nope', artist: 'Someone');
      for (final path in ['/a', '/b', '/c', '/d']) {
        await play(path, 100);
      }
      final lal = await db.historyPlaysMatching(0, 1000, ['lal']);
      expect(lal.rows.map((r) => r.path), ['/c', '/b']);
      final la = await db.historyPlaysMatching(0, 1000, ['la', 'lung']);
      expect(la.rows.map((r) => r.path), ['/a']);
      expect(la.rows.single.track!.title, 'Lạ Lùng');
      expect(la.rows.single.nth, 1);
      final mid = await db.historyPlaysMatching(0, 1000, ['al']);
      expect(mid.rows.map((r) => r.path), ['/c']);
    });

    test(
      'newest first, year bounds half-open, missing files never match',
      () async {
        await titled('/a', 'Lal');
        final early = await play('/a', 99);
        final first = await play('/a', 100);
        final second = await play('/a', 100);
        await play('/a', 200); // end bound excluded
        await play('/gone', 150); // not in the library
        final r = await db.historyPlaysMatching(100, 200, ['lal']);
        expect(r.rows.map((p) => p.id), [second, first]);
        expect(r.rows.map((p) => p.id), isNot(contains(early)));
        expect(r.truncated, isFalse);
      },
    );

    test('no terms give nothing; the limit sets the truncated flag', () async {
      await titled('/a', 'Lal');
      for (var i = 0; i < 4; i++) {
        await play('/a', 100 + i);
      }
      expect((await db.historyPlaysMatching(0, 1000, const [])).rows, isEmpty);
      final cut = await db.historyPlaysMatching(0, 1000, ['lal'], limit: 3);
      expect(cut.rows.map((p) => p.playedAt), [103, 102, 101]);
      expect(cut.truncated, isTrue);
      final fit = await db.historyPlaysMatching(0, 1000, ['lal'], limit: 4);
      expect(fit.rows, hasLength(4));
      expect(fit.truncated, isFalse);
    });
  });

  group('query plans', () {
    // SQLite prints aliases, not table names, so each query lists the names
    // it gives `plays`. No full scan of those; every search uses a plays_*
    // index.
    Future<void> expectIndexed(
      String sql,
      List<Object> args,
      Set<String> playsNames,
    ) async {
      final plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN $sql',
            variables: [for (final a in args) Variable(a)],
          )
          .get();
      final details = [for (final r in plan) r.read<String>('detail')];
      final names = playsNames.join('|');
      final scan = RegExp('^SCAN ($names)( |\$)');
      final search = RegExp('^SEARCH ($names) ');
      final searches = details.where(search.hasMatch).toList();
      expect(searches, isNotEmpty, reason: details.join('\n'));
      for (final d in details) {
        expect(scan.hasMatch(d), isFalse, reason: d);
      }
      for (final d in searches) {
        expect(d, matches(RegExp(r'USING (COVERING )?INDEX plays_')));
      }
    }

    test(
      'day counts, day plays, top range and track plays use indexes',
      () async {
        await expectIndexed(historyBucketSql, ['[0,1000,2000]'], {'plays'});
        await expectIndexed(historyDayBucketSql, ['[0,1000,2000]'], {'plays'});
        await expectIndexed(historyRangeSummarySql, [0, 100], {'plays'});
        await expectIndexed(historyDayPlaysSql, [0, 100], {'p', 'q'});
        await expectIndexed(historyTopRangeSql, [0, 100, 5], {'plays'});
        await expectIndexed(
          historyPlaysMatchingSql,
          [0, 100, '{title_sort} : (lal*)', 5],
          {'p', 'q'},
        );
        await expectIndexed(
          'SELECT id, played_at, listened_ms FROM plays WHERE path = ?1 '
          'ORDER BY played_at DESC, id DESC',
          ['/a'],
          {'plays'},
        );
      },
    );

    test('matching plays look songs up in the FTS index, then plays by path and range', () async {
      final plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN $historyPlaysMatchingSql',
            variables: [
              Variable.withInt(0),
              Variable.withInt(100),
              Variable.withString('{title_sort} : (lal*)'),
              Variable.withInt(5),
            ],
          )
          .get();
      final details = [for (final r in plan) r.read<String>('detail')];
      final text = details.join('\n');
      // The MATCH is answered by the FTS virtual table, not a table scan.
      expect(
        details,
        contains(
          matches(RegExp(r'^SCAN track_search VIRTUAL TABLE INDEX 0:M')),
        ),
        reason: text,
      );
      // Each matched song's plays come from the path + time-range index.
      expect(
        details,
        contains(
          'SEARCH p USING INDEX plays_path_played '
          '(path=? AND played_at>? AND played_at<?)',
        ),
        reason: text,
      );
      // The per-row latest-play lookup uses the played_at index.
      expect(
        details,
        contains(matches(RegExp(r'USING COVERING INDEX plays_played_at'))),
        reason: text,
      );
      expect(details.where((d) => d.startsWith('SCAN p')), isEmpty);
    });

    test('cover keys walk the played_at index, bounded, no sort', () async {
      final plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN $historyCoverKeysSql',
            variables: [Variable.withInt(1000)],
          )
          .get();
      final details = [for (final r in plan) r.read<String>('detail')];
      final text = details.join('\n');
      expect(text, contains('INDEX plays_played_at'), reason: text);
      expect(text, isNot(contains('TEMP B-TREE')), reason: text);
      expect(text, contains('SEARCH t'), reason: text);
    });

    test('all-time top scans only play_stats', () async {
      final plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN $historyTopAllSql',
            variables: [Variable.withInt(5)],
          )
          .get();
      for (final r in plan) {
        expect(r.read<String>('detail'), isNot(contains('plays ')));
      }
    });
  });
}
