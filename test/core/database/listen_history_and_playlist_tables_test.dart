import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_root_queries.dart';

// The SQL below is reference reading of the tables; the feature code owns the
// real queries.
const _statsByPathSql =
    'SELECT play_count, first_played_at, last_played_at FROM play_stats WHERE path = ?';
const _timelineSql =
    'SELECT id, path, played_at FROM plays ORDER BY played_at DESC, id DESC LIMIT ?';
const _topInRangeSql =
    'SELECT path, COUNT(*) AS n, MAX(played_at) AS last FROM plays '
    'WHERE played_at >= ? AND played_at < ? GROUP BY path '
    'ORDER BY n DESC, last ASC LIMIT ?';
const _playlistRowsSql =
    'SELECT e.id, e.path, t.id AS track_id, t.cover_key FROM playlist_entries e '
    'LEFT JOIN tracks t ON t.path = e.path WHERE e.playlist_id = ? '
    'ORDER BY e.position, e.id';

TracksCompanion _track(int rootId, String path, {String? coverKey}) =>
    TracksCompanion.insert(
      rootId: rootId,
      path: path,
      mtimeMs: 1,
      sizeBytes: 10,
      title: 'T',
      coverKey: Value(coverKey),
      addedAt: 100,
      updatedAt: 100,
    );

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'connection pragmas the triggers and cascades depend on are on',
    () async {
      final pragmas = await db
          .customSelect('PRAGMA recursive_triggers')
          .getSingle();
      expect(pragmas.data.values.single, 1);
      final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(fk.data.values.single, 1);
    },
  );

  Future<void> play(String path, int at, {int? listened, int? id}) => db
      .into(db.plays)
      .insert(
        PlaysCompanion.insert(
          id: Value.absentIfNull(id),
          path: path,
          playedAt: at,
          listenedMs: Value(listened),
        ),
      );

  Future<void> exec(String sql, [List<Object?> args = const []]) =>
      db.customUpdate(
        sql,
        variables: [for (final a in args) Variable(a)],
        updates: {db.plays},
        updateKind: UpdateKind.delete,
      );

  Future<List<QueryRow>> rows(String sql, [List<Object?> args = const []]) => db
      .customSelect(sql, variables: [for (final a in args) Variable(a)])
      .get();

  Future<List<int>> stats(String path) async {
    final r = await rows(_statsByPathSql, [path]);
    if (r.isEmpty) return const [];
    final d = r.single.data;
    return [
      d['play_count']! as int,
      d['first_played_at']! as int,
      d['last_played_at']! as int,
    ];
  }

  // play_stats equals GROUP BY over plays, in both directions.
  Future<void> expectStatsMatchPlays() async {
    String key(Map<String, Object?> d) =>
        '${d['path']}|${d['c']}|${d['f']}|${d['l']}';
    final expected = (await rows(
      'SELECT path, COUNT(*) AS c, MIN(played_at) AS f, MAX(played_at) AS l '
      'FROM plays GROUP BY path',
    )).map((r) => key(r.data)).toList()..sort();
    final actual = (await rows(
      'SELECT path, play_count AS c, first_played_at AS f, last_played_at AS l '
      'FROM play_stats',
    )).map((r) => key(r.data)).toList()..sort();
    expect(actual, expected);
  }

  Future<String> plan(String sql, [List<Object?> args = const []]) async =>
      (await rows(
        'EXPLAIN QUERY PLAN $sql',
        args,
      )).map((r) => r.read<String>('detail')).join('\n');

  group('plays and play stats', () {
    test(
      'the first play creates stats and later plays update count and range',
      () async {
        await play('/a', 100);
        expect(await stats('/a'), [1, 100, 100]);
        await play('/a', 200);
        expect(await stats('/a'), [2, 100, 200]);
        await play('/a', 50);
        expect(await stats('/a'), [3, 50, 200]);
        await play('/a', 150);
        expect(await stats('/a'), [4, 50, 200]);
      },
    );

    test('a play of a path that is in no track inserts fine', () async {
      await play('/nowhere.mp3', 1);
      expect(await db.select(db.tracks).get(), isEmpty);
      expect(await stats('/nowhere.mp3'), [1, 1, 1]);
    });

    test(
      'deleting the first, a middle and the last play recomputes the range',
      () async {
        for (final (id, at) in [(1, 10), (2, 20), (3, 30), (4, 40)]) {
          await play('/a', at, id: id);
        }
        await exec('DELETE FROM plays WHERE id = 1');
        expect(await stats('/a'), [3, 20, 40]);
        await exec('DELETE FROM plays WHERE id = 3');
        expect(await stats('/a'), [2, 20, 40]);
        await exec('DELETE FROM plays WHERE id = 4');
        expect(await stats('/a'), [1, 20, 20]);
      },
    );

    test('deleting the only remaining play removes the stats row', () async {
      await play('/a', 10, id: 1);
      await play('/b', 10, id: 2);
      await exec('DELETE FROM plays WHERE id = 1');
      expect(await stats('/a'), isEmpty);
      expect(await stats('/b'), [1, 10, 10]);
    });

    test('deleting all plays of a path removes its stats row only', () async {
      await play('/a', 10);
      await play('/a', 20);
      await play('/b', 30);
      await exec('DELETE FROM plays WHERE path = ?', ['/a']);
      expect(await stats('/a'), isEmpty);
      await expectStatsMatchPlays();
      expect(await stats('/b'), [1, 30, 30]);
    });

    test('one DELETE of every play empties the stats', () async {
      for (var i = 0; i < 20; i++) {
        await play('/p${i % 4}', i);
      }
      await exec('DELETE FROM plays');
      expect(await rows('SELECT 1 FROM play_stats'), isEmpty);
    });

    test(
      'a mixed sequence of inserts, deletes and re-inserts matches GROUP BY',
      () async {
        final paths = ['/a', '/b', '/c'];
        var at = 1000;
        for (var round = 0; round < 6; round++) {
          for (var i = 0; i < 9; i++) {
            // Times are deliberately out of order.
            await play(paths[(i + round) % 3], at + (i * 7919) % 101);
          }
          at += 50;
          await expectStatsMatchPlays();
          await exec(
            'DELETE FROM plays WHERE id IN '
            '(SELECT id FROM plays ORDER BY played_at LIMIT 4)',
          );
          await expectStatsMatchPlays();
          if (round == 3) {
            await exec('DELETE FROM plays WHERE path = ?', ['/b']);
            await expectStatsMatchPlays();
          }
        }
      },
    );

    test(
      'listened_ms may be null, and updating it leaves stats untouched',
      () async {
        await play('/a', 10, id: 1);
        expect((await rows('SELECT listened_ms FROM plays')).single.data, {
          'listened_ms': null,
        });
        await play('/a', 20, listened: 5, id: 2);
        await exec('UPDATE plays SET listened_ms = 99');
        expect(await stats('/a'), [2, 10, 20]);
        expect(
          (await rows('SELECT listened_ms FROM plays'))
              .map((r) => r.data['listened_ms']),
          [99, 99],
        );
      },
    );

    test('changing the path of a play moves it between stats rows', () async {
      await play('/a', 10, id: 1);
      await play('/a', 20, id: 2);
      await play('/b', 5, id: 3);
      await exec("UPDATE plays SET path = '/b' WHERE id = 2");
      expect(await stats('/a'), [1, 10, 10]);
      expect(await stats('/b'), [2, 5, 20]);
      await exec("UPDATE plays SET path = '/c' WHERE id = 1");
      expect(await stats('/a'), isEmpty);
      expect(await stats('/c'), [1, 10, 10]);
      await expectStatsMatchPlays();
    });

    test('changing played_at recomputes the range of its path', () async {
      await play('/a', 10, id: 1);
      await play('/a', 20, id: 2);
      await exec('UPDATE plays SET played_at = 30 WHERE id = 1');
      expect(await stats('/a'), [2, 20, 30]);
      await exec('UPDATE plays SET played_at = 5 WHERE id = 2');
      expect(await stats('/a'), [2, 5, 30]);
      await expectStatsMatchPlays();
    });

    group('drift write modes', () {
      PlaysCompanion row(int id, String path, int at) =>
          PlaysCompanion.insert(id: Value(id), path: path, playedAt: at);

      test('every insert mode keeps stats equal to GROUP BY', () async {
        await db.into(db.plays).insert(row(1, '/a', 10));
        await expectStatsMatchPlays();
        await db
            .into(db.plays)
            .insert(row(2, '/a', 20), mode: InsertMode.insertOrReplace);
        await expectStatsMatchPlays();
        // Re-saving an existing id replaces the row.
        await db
            .into(db.plays)
            .insert(row(2, '/b', 25), mode: InsertMode.insertOrReplace);
        await expectStatsMatchPlays();
        await db
            .into(db.plays)
            .insert(row(2, '/a', 99), mode: InsertMode.insertOrIgnore);
        await expectStatsMatchPlays();
        await db
            .into(db.plays)
            .insert(row(3, '/a', 30), mode: InsertMode.insertOrAbort);
        await expectStatsMatchPlays();
        await db
            .into(db.plays)
            .insert(row(4, '/a', 40), mode: InsertMode.insertOrFail);
        await expectStatsMatchPlays();
        await db
            .into(db.plays)
            .insert(row(5, '/a', 50), mode: InsertMode.replace);
        await expectStatsMatchPlays();
        expect(await stats('/a'), [4, 10, 50]);
      });

      test(
        'insertOnConflictUpdate and replace() with unchanged keys do not throw',
        () async {
          await db.into(db.plays).insert(row(1, '/a', 10));
          await db.into(db.plays).insertOnConflictUpdate(row(1, '/a', 10));
          await expectStatsMatchPlays();
          await db.into(db.plays).insertOnConflictUpdate(row(1, '/b', 12));
          await expectStatsMatchPlays();

          final saved = await (db.select(
            db.plays,
          )..where((p) => p.id.equals(1))).getSingle();
          expect(
            await db
                .update(db.plays)
                .replace(saved.copyWith(listenedMs: const Value(7))),
            isTrue,
          );
          await expectStatsMatchPlays();
          expect(await stats('/b'), [1, 12, 12]);
          expect((await db.select(db.plays).getSingle()).listenedMs, 7);

          // A replace() that changes the keys moves the play.
          await db
              .update(db.plays)
              .replace(saved.copyWith(path: '/c', playedAt: 3));
          await expectStatsMatchPlays();
          expect(await stats('/b'), isEmpty);
          expect(await stats('/c'), [1, 3, 3]);
        },
      );

      test('batch insertAll and delete().go() keep stats right', () async {
        await db.batch((b) {
          b.insertAll(db.plays, [
            row(1, '/a', 10),
            row(2, '/a', 20),
            row(3, '/b', 5),
          ]);
        });
        await expectStatsMatchPlays();
        await db.batch((b) {
          b.insertAll(db.plays, [
            row(4, '/b', 1),
            row(1, '/c', 2),
          ], mode: InsertMode.insertOrReplace);
        });
        await expectStatsMatchPlays();
        await (db.delete(db.plays)..where((p) => p.path.equals('/b'))).go();
        await expectStatsMatchPlays();
        await db.delete(db.plays).go();
        expect(await rows('SELECT 1 FROM play_stats'), isEmpty);
      });

      test('a play_stats watcher refreshes after insert and delete', () async {
        final emissions = <int>[];
        final sub = db
            .select(db.playStats)
            .watch()
            .listen((r) => emissions.add(r.length));
        addTearDown(sub.cancel);
        Future<void> settle() =>
            Future<void>.delayed(const Duration(milliseconds: 50));

        await settle();
        expect(emissions.last, 0);
        await db.into(db.plays).insert(row(1, '/a', 10));
        await settle();
        expect(emissions.last, 1);
        await db.delete(db.plays).go();
        await settle();
        expect(emissions.last, 0);
      });
    });

    test(
      'removing a root keeps plays and stats, and a returning file re-matches',
      () async {
        final root = (await db.addRoots(['/m'], now: 1)).single;
        await db.upsertTracks([_track(root, '/m/a.mp3')]);
        final firstId = (await db.select(db.tracks).getSingle()).id;
        await play('/m/a.mp3', 10);
        await play('/m/a.mp3', 20);

        await db.removeRoot(root);
        expect(await db.select(db.tracks).get(), isEmpty);
        expect(await db.select(db.plays).get(), hasLength(2));
        expect(await stats('/m/a.mp3'), [2, 10, 20]);

        final again = (await db.addRoots(['/m'], now: 2)).single;
        await db.upsertTracks([_track(again, '/m/a.mp3')]);
        final joined = await rows(
          'SELECT tracks.id AS id, play_stats.play_count AS n FROM play_stats '
          'JOIN tracks ON tracks.path = play_stats.path',
        );
        expect(joined, hasLength(1));
        expect(joined.single.data['n'], 2);
        expect(joined.single.data['id'], isNot(firstId));
      },
    );

    group('query plans', () {
      test('the stats lookup uses the primary key', () async {
        expect(
          await plan(_statsByPathSql, ['/a']),
          contains('sqlite_autoindex_play_stats'),
        );
      });

      test(
        'the timeline is served by plays_played_at without a full sort',
        () async {
          final d = await plan(_timelineSql, [10]);
          expect(d, contains('plays_played_at'));
          // A partial sort for the id tie-break is fine; a full one is not.
          expect(d, isNot(contains('USE TEMP B-TREE FOR ORDER BY')));
        },
      );

      test('top in a range scans the covering played_at index', () async {
        final d = await plan(_topInRangeSql, [0, 100, 10]);
        expect(d, contains('COVERING INDEX plays_played_at'));
      });
    });
  });

  group('playlists', () {
    Future<int> playlist(String name) => db
        .into(db.playlists)
        .insert(PlaylistsCompanion.insert(name: name, createdAt: 1));

    Future<void> entry(int playlistId, String path, int position) => db
        .into(db.playlistEntries)
        .insert(
          PlaylistEntriesCompanion.insert(
            playlistId: playlistId,
            path: path,
            position: position,
          ),
        );

    test(
      'the same path twice gives two entries read in position, id order',
      () async {
        final pl = await playlist('p');
        await entry(pl, '/a', 1);
        await entry(pl, '/b', 0);
        await entry(pl, '/a', 1);
        final r = await rows(_playlistRowsSql, [pl]);
        expect(r.map((e) => e.data['path']), ['/b', '/a', '/a']);
        final ids = r.map((e) => e.data['id']! as int).toList();
        expect(ids.toSet(), hasLength(3));
        expect(ids[1], lessThan(ids[2]));
      },
    );

    test('shifting positions up leaves them contiguous', () async {
      final pl = await playlist('p');
      for (var i = 0; i < 4; i++) {
        await entry(pl, '/t$i', i);
      }
      await exec(
        'UPDATE playlist_entries SET position = position + 1 '
        'WHERE playlist_id = ? AND position >= ?',
        [pl, 1],
      );
      await entry(pl, '/new', 1);
      final r = await rows(_playlistRowsSql, [pl]);
      expect(r.map((e) => e.data['path']), [
        '/t0',
        '/new',
        '/t1',
        '/t2',
        '/t3',
      ]);
      final positions = await rows(
        'SELECT position FROM playlist_entries WHERE playlist_id = ? ORDER BY position',
        [pl],
      );
      expect(positions.map((e) => e.data['position']), [0, 1, 2, 3, 4]);
    });

    test('deleting a playlist removes its entries and keeps others', () async {
      final a = await playlist('a');
      final b = await playlist('b');
      await entry(a, '/x', 0);
      await entry(a, '/y', 1);
      await entry(b, '/x', 0);
      await (db.delete(db.playlists)..where((p) => p.id.equals(a))).go();
      final left = await db.select(db.playlistEntries).get();
      expect(left.map((e) => e.playlistId), [b]);
    });

    test('an entry for an unknown playlist is rejected', () async {
      await expectLater(entry(999, '/x', 0), throwsA(anything));
    });

    test(
      'removing a root keeps entries, which match again when the file returns',
      () async {
        final root = (await db.addRoots(['/m'], now: 1)).single;
        await db.upsertTracks([_track(root, '/m/a.mp3', coverKey: 'c1')]);
        final pl = await playlist('p');
        await entry(pl, '/m/a.mp3', 0);
        expect(
          (await rows(_playlistRowsSql, [pl])).single.data['cover_key'],
          'c1',
        );

        await db.removeRoot(root);
        var r = (await rows(_playlistRowsSql, [pl])).single.data;
        expect(r['path'], '/m/a.mp3');
        expect(r['track_id'], isNull);
        expect(r['cover_key'], isNull);

        final again = (await db.addRoots(['/m'], now: 2)).single;
        await db.upsertTracks([_track(again, '/m/a.mp3', coverKey: 'c2')]);
        final newId = (await db.select(db.tracks).getSingle()).id;
        r = (await rows(_playlistRowsSql, [pl])).single.data;
        expect(r['track_id'], newId);
        expect(r['cover_key'], 'c2');
      },
    );

    test(
      'playlist rows use the order index and the track path index',
      () async {
        final d = await plan(_playlistRowsSql, [1]);
        expect(d, contains('playlist_entries_order'));
        expect(d, contains('sqlite_autoindex_tracks'));
        expect(d, isNot(contains('TEMP B-TREE')));
      },
    );
  });
}
