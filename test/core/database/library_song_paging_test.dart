import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_song_paging.dart';

import 'songs_reference_query.dart';

TracksCompanion _row(
  int rootId,
  int n, {
  String? title,
  String? artist,
  String? album,
  int? year,
  int? durationMs,
  int addedAt = 1,
}) => TracksCompanion.insert(
  rootId: rootId,
  path: '/m/$n.flac',
  mtimeMs: 1,
  sizeBytes: 1,
  title: title ?? 'T$n',
  artist: Value(artist),
  album: Value(album),
  year: Value(year),
  durationMs: Value(durationMs),
  addedAt: addedAt,
  updatedAt: addedAt,
);

void main() {
  late LibraryDatabase db;
  late int rootId;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  Future<void> insertMany(int count) => db.upsertTracks([
    for (var i = 0; i < count; i++) _row(rootId, i, title: 'T${i % 7}'),
  ]);

  group('songIds', () {
    test(
      'match songs() for every order and direction, ties included',
      () async {
        await db.upsertTracks([
          _row(
            rootId,
            0,
            title: 'b',
            artist: 'Y',
            album: 'P',
            year: 2000,
            durationMs: 3,
          ),
          _row(
            rootId,
            1,
            title: 'a',
            artist: 'X',
            year: 1990,
            durationMs: 9,
            addedAt: 5,
          ),
          _row(rootId, 2, title: 'a', artist: 'X', album: 'Q', addedAt: 5),
          _row(
            rootId,
            3,
            title: 'Émile',
            artist: 'Éric',
            album: 'Écho',
            year: 2000,
          ),
          _row(
            rootId,
            4,
            title: 'Zoé',
            artist: 'eric',
            album: 'echo',
            year: 2000,
          ),
          _row(rootId, 5, title: 'emile', durationMs: 3),
          _row(rootId, 6, title: 'a', artist: 'X', durationMs: 9),
        ]);
        for (final order in SongOrder.values) {
          for (final desc in [false, true]) {
            final expected = [
              for (final t in await db.songs(order: order, descending: desc))
                t.id,
            ];
            expect(
              await db.songIds(order: order, descending: desc),
              expected,
              reason: '${order.name} desc=$desc',
            );
          }
        }
      },
    );

    test('match songs() on 20k rows with many ties, every order', () async {
      await db.upsertTracks([
        for (var i = 0; i < 20000; i++)
          _row(
            rootId,
            i,
            title: 'T${i % 50}',
            artist: i % 3 == 0 ? null : 'Artist ${i % 40}',
            album: i % 4 == 0 ? null : 'Album ${i % 30}',
            year: i % 5 == 0 ? null : 1980 + i % 20,
            durationMs: i % 7 == 0 ? null : i % 90,
            addedAt: i % 100,
          ),
      ]);
      for (final order in SongOrder.values) {
        for (final desc in [false, true]) {
          final expected = [
            for (final t in await db.songs(order: order, descending: desc))
              t.id,
          ];
          expect(
            await db.songIds(order: order, descending: desc),
            expected,
            reason: '${order.name} desc=$desc',
          );
        }
      }
    });

    test('title order walks the title_sort index', () async {
      final rows = await db
          .customSelect(
            'EXPLAIN QUERY PLAN SELECT id FROM tracks '
            'ORDER BY ${songsOrderSql(SongOrder.title)}',
          )
          .get();
      final plan = rows.map((r) => r.read<String>('detail')).join('\n');
      expect(plan, contains('tracks_title_sort'));
      expect(plan, isNot(contains('TEMP B-TREE')));
    });
  });

  group('songsPage and empty library', () {
    test('no tracks, no ids and no rows', () async {
      expect(await db.songIds(), isEmpty);
      expect(await db.songsPage(), isEmpty);
    });

    test('the page is the start of songs() in every order', () async {
      await insertMany(30);
      for (final order in SongOrder.values) {
        final all = await db.songs(order: order, descending: true);
        final page = await db.songsPage(
          order: order,
          descending: true,
          limit: 7,
        );
        expect(
          [for (final t in page) t.id],
          [for (final t in all.take(7)) t.id],
        );
      }
    });
  });

  group('songsByIds', () {
    test(
      'returns rows in the order of the ids and drops missing ids',
      () async {
        await insertMany(5);
        final all = await db.songIds();
        final ask = [all[3], 9999, all[0], all[3], all[2]];
        final got = await db.songsByIds(ask);
        expect([for (final t in got) t.id], [all[3], all[0], all[3], all[2]]);
      },
    );

    test('reads more than one page of ids', () async {
      await insertMany(450);
      final ids = (await db.songIds()).reversed.toList();
      final got = await db.songsByIds(ids);
      expect([for (final t in got) t.id], ids);
    });

    test('empty ids read nothing', () async {
      expect(await db.songsByIds(const []), isEmpty);
    });
  });

  group('songQueueFrom', () {
    test('returns the list and the index of the track', () async {
      await insertMany(10);
      final expected = await db.songs(
        order: SongOrder.artist,
        descending: true,
      );
      final (tracks, start) = await db.songQueueFrom(
        expected[6].id,
        order: SongOrder.artist,
        descending: true,
      );
      expect([for (final t in tracks) t.id], [for (final t in expected) t.id]);
      expect(start, 6);
    });

    test('a deleted track gives no start', () async {
      await insertMany(10);
      final ids = await db.songIds();
      await db.deleteTracksById([ids[4]]);
      final (tracks, start) = await db.songQueueFrom(ids[4]);
      expect(start, isNull);
      expect(tracks, hasLength(9));
    });

    test('reads a library larger than one chunk', () async {
      await insertMany(4500);
      final expected = await db.songs();
      final (tracks, start) = await db.songQueueFrom(expected[4321].id);
      expect([for (final t in tracks) t.id], [for (final t in expected) t.id]);
      expect(start, 4321);
    });
  });
}
