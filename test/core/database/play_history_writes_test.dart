import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/play_history_writes.dart';

import 'library_database_test.dart' show track;

void main() {
  late LibraryDatabase db;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    final roots = await db.addRoots(['/music'], now: 1);
    await db.upsertTracks([
      track(roots.single, '/music/a.flac'),
      track(roots.single, '/music/b.flac'),
    ]);
  });
  tearDown(() => db.close());

  Future<List<Play>> allPlays() => db.select(db.plays).get();
  Future<List<PlayStat>> allStats() => db.select(db.playStats).get();

  test('inserts a play of a library track and counts it', () async {
    final id = await db.insertLibraryPlay(
      path: '/music/a.flac',
      playedAt: 5000,
      listenedMs: 90000,
    );

    expect(id, isNotNull);
    final play = (await allPlays()).single;
    expect(play.id, id);
    expect(play.path, '/music/a.flac');
    expect(play.playedAt, 5000);
    expect(play.listenedMs, 90000);
    final stat = (await allStats()).single;
    expect(stat.playCount, 1);
    expect(stat.firstPlayedAt, 5000);
    expect(stat.lastPlayedAt, 5000);
  });

  test('writes nothing for a path that is not a library track', () async {
    final id = await db.insertLibraryPlay(
      path: '/elsewhere/x.flac',
      playedAt: 1,
      listenedMs: 1,
    );

    expect(id, isNull);
    expect(await allPlays(), isEmpty);
    expect(await allStats(), isEmpty);
  });

  test('updating listened_ms leaves the stats alone', () async {
    final id = (await db.insertLibraryPlay(
      path: '/music/a.flac',
      playedAt: 5000,
      listenedMs: 1000,
    ))!;

    expect(await db.setPlayListened(id, 120000), isTrue);

    expect((await allPlays()).single.listenedMs, 120000);
    final stat = (await allStats()).single;
    expect(
      (stat.playCount, stat.firstPlayedAt, stat.lastPlayedAt),
      (1, 5000, 5000),
    );
  });

  test(
    'clearing removes plays and stats; a late update recreates nothing',
    () async {
      final id = (await db.insertLibraryPlay(
        path: '/music/a.flac',
        playedAt: 1,
        listenedMs: 1,
      ))!;
      await db.insertLibraryPlay(
        path: '/music/b.flac',
        playedAt: 2,
        listenedMs: 1,
      );

      expect(await db.clearPlayHistory(), 2);

      expect(await allPlays(), isEmpty);
      expect(await allStats(), isEmpty);
      expect(await db.setPlayListened(id, 5), isFalse);
      expect(await allPlays(), isEmpty);
      expect(await db.clearPlayHistory(), 0);
    },
  );

  test('a play_stats watcher re-emits after an insert and a clear', () async {
    final counts = <int>[];
    final sub = db
        .select(db.playStats)
        .watch()
        .listen((rows) => counts.add(rows.length));
    addTearDown(sub.cancel);
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 50));

    await settle();
    expect(counts.last, 0);
    await db.insertLibraryPlay(
      path: '/music/a.flac',
      playedAt: 1,
      listenedMs: 1,
    );
    await settle();
    expect(counts.last, 1);
    await db.clearPlayHistory();
    await settle();
    expect(counts.last, 0);
  });

  group('clearing a range', () {
    Future<void> seed(String path, List<int> at) async {
      for (final t in at) {
        await db.insertLibraryPlay(path: path, playedAt: t, listenedMs: 1);
      }
    }

    /// `play_stats` against a `GROUP BY` over `plays`.
    Future<void> expectStatsMatchPlays() async {
      Future<List<Map<String, Object?>>> read(String sql) async => [
        for (final r in await db.customSelect(sql).get()) r.data,
      ];
      expect(
        await read(
          'SELECT path, play_count, first_played_at, last_played_at '
          'FROM play_stats ORDER BY path',
        ),
        await read(
          'SELECT path, count(*) AS play_count, min(played_at) AS '
          'first_played_at, max(played_at) AS last_played_at '
          'FROM plays GROUP BY path ORDER BY path',
        ),
      );
    }

    test(
      'removes only the plays in [from, to) and keeps stats exact',
      () async {
        // a: before, on from, inside, on to (kept), after, future-dated.
        await seed('/music/a.flac', [50, 100, 150, 200, 250, 9000000000000]);
        await seed('/music/b.flac', [120, 130]);

        expect(await db.clearPlayHistory(from: 100, to: 200), 4);

        expect((await allPlays()).map((p) => p.playedAt).toList()..sort(), [
          50,
          200,
          250,
          9000000000000,
        ]);
        final stat = (await allStats()).single;
        expect(stat.path, '/music/a.flac');
        expect(stat.playCount, 4);
        expect(stat.firstPlayedAt, 50);
        expect(stat.lastPlayedAt, 9000000000000);
        await expectStatsMatchPlays();
      },
    );

    test('a path whose plays all lie inside loses its stats row', () async {
      await seed('/music/b.flac', [120, 130]);
      await seed('/music/a.flac', [10, 500]);

      expect(await db.clearPlayHistory(from: 100, to: 200), 2);

      expect((await allStats()).map((s) => s.path), ['/music/a.flac']);
      await expectStatsMatchPlays();
    });

    test('an open side reaches the end of time', () async {
      await seed('/music/a.flac', [10, 100, 500]);
      expect(await db.clearPlayHistory(from: 100), 2);
      await seed('/music/a.flac', [600]);
      expect(await db.clearPlayHistory(to: 550), 1);
      expect((await allPlays()).single.playedAt, 600);
      await expectStatsMatchPlays();
    });

    test('no bounds removes every play and empties the stats', () async {
      await seed('/music/a.flac', [10, 100]);
      await seed('/music/b.flac', [5]);
      expect(await db.clearPlayHistory(), 3);
      expect(await allPlays(), isEmpty);
      expect(await allStats(), isEmpty);
    });

    test('an empty range removes nothing', () async {
      await seed('/music/a.flac', [10, 100]);
      expect(await db.clearPlayHistory(from: 20, to: 90), 0);
      expect(await allPlays(), hasLength(2));
      await expectStatsMatchPlays();
    });
  });
}
