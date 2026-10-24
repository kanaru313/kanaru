import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/home_queries.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';

void main() {
  late LibraryDatabase db;
  late int rootId;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    await db.addRoots(['/m'], now: 1);
    rootId = (await db.select(db.libraryRoots).getSingle()).id;
  });
  tearDown(() => db.close());

  Future<void> track(
    String path, {
    String? artist = 'A',
    String? album,
    String? albumArtist,
    int addedAt = 1,
    int mtimeMs = 1,
    int? durationMs,
  }) => db.upsertTracks([
    TracksCompanion.insert(
      rootId: rootId,
      path: path,
      mtimeMs: mtimeMs,
      sizeBytes: 1,
      title: 'T $path',
      artist: Value(artist),
      album: Value(album),
      albumArtist: Value(albumArtist),
      durationMs: Value(durationMs),
      addedAt: addedAt,
      updatedAt: 1,
    ),
  ]);

  Future<void> play(String path, int at) =>
      db.into(db.plays).insert(PlaysCompanion.insert(path: path, playedAt: at));

  List<String> paths(List<TrackListItem> items) => [
    for (final i in items) i.path,
  ];

  test('homeHasTracks follows the library', () async {
    expect(await db.homeHasTracks(), isFalse);
    await track('/a');
    expect(await db.homeHasTracks(), isTrue);
  });

  group('homeRecentlyPlayed', () {
    test(
      'latest listen first, one row per track, missing tracks dropped',
      () async {
        for (final p in ['/a', '/b', '/c']) {
          await track(p);
        }
        await play('/a', 10);
        await play('/b', 20);
        await play('/a', 30);
        await play('/gone', 40);
        await play('/c', 5);
        expect(paths(await db.homeRecentlyPlayed(limit: 10)), [
          '/a',
          '/b',
          '/c',
        ]);
      },
    );

    test('limit and offset page the list', () async {
      for (var i = 0; i < 5; i++) {
        await track('/t$i');
        await play('/t$i', 10 + i);
      }
      expect(paths(await db.homeRecentlyPlayed(limit: 2)), ['/t4', '/t3']);
      expect(paths(await db.homeRecentlyPlayed(limit: 2, offset: 2)), [
        '/t2',
        '/t1',
      ]);
      expect(await db.homeRecentlyPlayed(limit: 2, offset: 9), isEmpty);
    });

    test('equal last listen breaks the tie by path', () async {
      await track('/b');
      await track('/a');
      await play('/b', 10);
      await play('/a', 10);
      expect(paths(await db.homeRecentlyPlayed(limit: 5)), ['/a', '/b']);
    });
  });

  group('homeRecentlyAdded', () {
    test('newest added_at is null on an empty library', () async {
      expect(await db.homeNewestAddedAt(), isNull);
      await track('/a', addedAt: 7);
      await track('/b', addedAt: 9);
      expect(await db.homeNewestAddedAt(), 9);
    });

    test('since filters inclusively, null returns everything', () async {
      await track('/old', addedAt: 100);
      await track('/edge', addedAt: 200);
      await track('/new', addedAt: 300);
      expect(paths(await db.homeRecentlyAdded(since: 200, limit: 10)), [
        '/new',
        '/edge',
      ]);
      expect(paths(await db.homeRecentlyAdded(limit: 10)), [
        '/new',
        '/edge',
        '/old',
      ]);
    });

    test('ties go to the newer file time, then the higher id', () async {
      await track('/a', addedAt: 5, mtimeMs: 1);
      await track('/b', addedAt: 5, mtimeMs: 9);
      await track('/c', addedAt: 5, mtimeMs: 9);
      expect(paths(await db.homeRecentlyAdded(limit: 10)), ['/c', '/b', '/a']);
      expect(paths(await db.homeRecentlyAdded(limit: 1, offset: 1)), ['/b']);
    });
  });

  group('homeMemories', () {
    test('counts only plays inside [start, end)', () async {
      await track('/a');
      await track('/b');
      await play('/a', 99); // before
      await play('/a', 100); // start, in
      await play('/b', 150);
      await play('/b', 160);
      await play('/a', 200); // end, out
      expect(paths(await db.homeMemories(start: 100, end: 200, limit: 10)), [
        '/b',
        '/a',
      ]);
    });

    test('plays, then the latest play, then path', () async {
      for (final p in ['/a', '/b', '/c', '/d']) {
        await track(p);
      }
      await play('/a', 110);
      await play('/b', 120);
      await play('/c', 130);
      await play('/c', 131);
      await play('/d', 120);
      expect(paths(await db.homeMemories(start: 100, end: 200, limit: 10)), [
        '/c',
        '/b',
        '/d',
        '/a',
      ]);
    });

    test('a missing track does not shift the offset', () async {
      await track('/a');
      await track('/b');
      await track('/c');
      for (var i = 0; i < 3; i++) {
        await play('/gone', 110 + i); // most plays, not in the library
      }
      await play('/a', 120);
      await play('/a', 121);
      await play('/b', 130);
      await play('/c', 125);
      Future<List<String>> page(int limit, int offset) async => paths(
        await db.homeMemories(
          start: 100,
          end: 200,
          limit: limit,
          offset: offset,
        ),
      );
      expect(await page(2, 0), ['/a', '/b']);
      expect(await page(2, 2), ['/c']);
      expect(await page(1, 1), ['/b']);
    });
  });

  group('homeRecentAlbums', () {
    test(
      'latest listen first, counts every track, skips no-album tracks',
      () async {
        await track('/x1', album: 'X', albumArtist: 'AA', durationMs: 10);
        await track('/x2', album: 'X', albumArtist: 'AA', durationMs: 20);
        await track('/y1', album: 'Y', albumArtist: 'BB');
        await track('/single', album: null);
        await play('/x1', 10);
        await play('/y1', 20);
        await play('/single', 30);
        await play('/x2', 40);
        await play('/gone', 50);
        final albums = await db.homeRecentAlbums(limit: 10);
        expect([for (final a in albums) a.title], ['X', 'Y']);
        expect(albums.first.trackCount, 2); // /x2 played, /x1 too, both counted
        expect(albums.first.durationMs, 30);
        expect(await db.homeRecentAlbums(limit: 1, offset: 1), hasLength(1));
        expect(
          (await db.homeRecentAlbums(limit: 1, offset: 1)).single.title,
          'Y',
        );
      },
    );

    test('equal last listen breaks the tie by keys; offset pages', () async {
      await track('/b1', album: 'B', albumArtist: 'AA');
      await track('/a1', album: 'A', albumArtist: 'AA');
      await track('/c1', album: 'C', albumArtist: 'AA');
      await play('/b1', 10);
      await play('/a1', 10);
      await play('/c1', 5);
      List<String> titles(List<AlbumSummary> l) => [for (final a in l) a.title];
      expect(titles(await db.homeRecentAlbums(limit: 10)), ['A', 'B', 'C']);
      expect(titles(await db.homeRecentAlbums(limit: 1)), ['A']);
      expect(titles(await db.homeRecentAlbums(limit: 1, offset: 1)), ['B']);
      expect(titles(await db.homeRecentAlbums(limit: 5, offset: 2)), ['C']);
    });

    test('an album with unplayed tracks still counts them', () async {
      await track('/a1', album: 'X', albumArtist: 'AA');
      await track('/a2', album: 'X', albumArtist: 'AA');
      await track('/a3', album: 'X', albumArtist: 'AA');
      await play('/a1', 5);
      final albums = await db.homeRecentAlbums(limit: 10);
      expect(albums.single.trackCount, 3);
      expect(albums.single, isA<AlbumSummary>());
    });
  });

  group('homeRecentArtists', () {
    test(
      'multi artist tracks give one row per artist, matching the tab',
      () async {
        await track(
          '/a',
          artist: 'Alpha feat. Beta',
          album: 'X',
          albumArtist: 'Alpha',
        );
        await track('/b', artist: 'Beta', album: 'Y', albumArtist: 'Beta');
        await track('/c', artist: 'Beta', album: 'Y', albumArtist: 'Beta');
        await track('/d', artist: 'Gamma');
        await play('/a', 10);
        await play('/d', 20);
        await play('/gone', 30);
        final recent = await db.homeRecentArtists(limit: 10);
        final all = {for (final c in await db.artistCredits()) c.key: c};
        expect(
          recent.map((c) => c.name),
          containsAll(['Alpha', 'Beta', 'Gamma']),
        );
        expect(recent, hasLength(3));
        expect(recent.first.name, 'Gamma');
        for (final c in recent) {
          final expected = all[c.key]!;
          expect(c.name, expected.name);
          expect(c.trackCount, expected.trackCount);
          expect(c.albumCount, expected.albumCount);
        }
        final beta = recent.firstWhere((c) => c.name == 'Beta');
        expect(beta.trackCount, 3); // played once, counted over every credit
      },
    );

    test('limit and offset page the artists', () async {
      for (var i = 0; i < 4; i++) {
        await track('/t$i', artist: 'Art$i');
        await play('/t$i', 10 + i);
      }
      expect((await db.homeRecentArtists(limit: 2)).map((c) => c.name), [
        'Art3',
        'Art2',
      ]);
      expect(
        (await db.homeRecentArtists(limit: 2, offset: 2)).map((c) => c.name),
        ['Art1', 'Art0'],
      );
    });
  });

  group('query plans', () {
    Future<void> expectPlan(
      String sql,
      List<Object?> args, {
      required Set<String> noScan,
    }) async {
      final plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN $sql',
            variables: [for (final a in args) Variable(a)],
          )
          .get();
      final details = [for (final r in plan) r.read<String>('detail')];
      final scan = RegExp('^SCAN (${noScan.join('|')})( |\$)');
      for (final d in details) {
        expect(scan.hasMatch(d), isFalse, reason: details.join('\n'));
      }
    }

    setUp(() async {
      for (var i = 0; i < 50; i++) {
        await track(
          '/t$i',
          artist: 'Art${i % 7}',
          album: 'Alb${i % 9}',
          albumArtist: 'AA${i % 9}',
          addedAt: 1000 + i,
        );
      }
      for (var i = 0; i < 20; i++) {
        await play('/t$i', 100 + i);
      }
    });

    Future<void> expectAllPlans() async {
      const plays = {'plays', 'p'};
      const both = {'plays', 'p', 'tracks', 't', 'k'};
      await expectPlan(homeRecentlyPlayedSql, [10, 0], noScan: both);
      await expectPlan(homeRecentlyAddedSql, [null, 10, 0], noScan: plays);
      await expectPlan(homeRecentlyAddedSql, [5, 10, 0], noScan: plays);
      await expectPlan(homeMemoriesSql, [100, 120, 10, 0], noScan: both);
      await expectPlan(homeRecentAlbumsSql, [10, 0], noScan: both);
      await expectPlan(homeRecentArtistsSql, [10, 0], noScan: {...both, 'ta'});
    }

    // A real database never has sqlite_stat1, so check both states.
    test('no query scans plays; history reads do not scan tracks', () async {
      await expectAllPlans();
    });

    // The newest rows come off `tracks_added_at`, so a library of any size
    // reads only the rows of the page.
    Future<List<String>> addedPlan(List<Object?> args) async {
      final plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN $homeRecentlyAddedSql',
            variables: [for (final a in args) Variable(a)],
          )
          .get();
      return [for (final r in plan) r.read<String>('detail')];
    }

    test('a bounded recently added read uses the added_at index', () async {
      final details = await addedPlan([1040, 10, 0]);
      expect(
        details.any((d) => d.contains('tracks_added_at')),
        isTrue,
        reason: details.join('\n'),
      );
    });

    test('an unbounded read returns the rows the OR form did', () async {
      const orForm =
          'SELECT t.path FROM tracks AS t '
          'WHERE (?1 IS NULL OR t.added_at >= ?1) '
          'ORDER BY t.added_at DESC, t.mtime_ms DESC, t.id DESC '
          'LIMIT ?2 OFFSET ?3';
      for (final since in <int?>[null, 1020, 5000]) {
        final old = await db
            .customSelect(
              orForm,
              variables: [
                Variable<int>(since),
                Variable.withInt(30),
                Variable.withInt(5),
              ],
            )
            .get();
        final now = await db.homeRecentlyAdded(
          since: since,
          limit: 30,
          offset: 5,
        );
        expect(paths(now), [for (final r in old) r.read<String>('path')]);
      }
      expect(await db.homeRecentlyAdded(limit: 1000), hasLength(50));
    });

    test('an unbounded recently added read does not scan plays', () async {
      final details = await addedPlan([null, 10, 0]);
      expect(
        details.any((d) => d.contains('tracks_added_at')),
        isTrue,
        reason: details.join('\n'),
      );
    });

    test('same plans after ANALYZE', () async {
      await db.customStatement('ANALYZE');
      await expectAllPlans();
    });
  });
}
