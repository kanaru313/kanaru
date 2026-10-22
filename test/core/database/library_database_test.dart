import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';

import 'songs_reference_query.dart';

TracksCompanion track(
  int rootId,
  String path, {
  String title = 'T',
  String? artist,
  int mtimeMs = 1,
  int now = 100,
}) => TracksCompanion.insert(
  rootId: rootId,
  path: path,
  mtimeMs: mtimeMs,
  sizeBytes: 10,
  title: title,
  artist: Value(artist),
  addedAt: now,
  updatedAt: now,
);

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('roots', () {
    test('rejects a duplicate path', () async {
      await db.addRoots(['/music'], now: 1);
      await expectLater(db.addRoots(['/music'], now: 2), throwsA(anything));
      expect((await db.roots()).length, 1);
    });

    test('adds several roots, or none when one fails', () async {
      expect(await db.addRoots(['/a', '/b'], now: 1), hasLength(2));
      await expectLater(db.addRoots(['/c', '/a'], now: 2), throwsA(anything));
      expect((await db.roots()).map((r) => r.path), ['/a', '/b']);
    });

    test('hasLibraryRoots and markRootScanned', () async {
      expect(await db.hasLibraryRoots(), isFalse);
      final id = (await db.addRoots(['/a'], now: 1)).single;
      expect(await db.hasLibraryRoots(), isTrue);
      expect((await db.roots()).single.lastScanAt, isNull);
      await db.markRootScanned(id, 50);
      expect((await db.roots()).single.lastScanAt, 50);
    });
  });

  group('tracks', () {
    late int rootId;
    setUp(() async => rootId = (await db.addRoots(['/m'], now: 1)).single);

    test('re-upsert keeps id, addedAt and rootId, updates the rest', () async {
      final other = (await db.addRoots(['/other'], now: 1)).single;
      await db.upsertTracks([track(rootId, '/m/a.mp3', title: 'Old')]);
      final first = await db.select(db.tracks).getSingle();

      await db.upsertTracks([
        track(other, '/m/a.mp3', title: 'New', artist: 'Ann', now: 200),
      ]);
      final second = await db.select(db.tracks).getSingle();

      expect(second.id, first.id);
      expect(second.addedAt, 100);
      expect(second.rootId, rootId);
      expect(second.title, 'New');
      expect(second.artist, 'Ann');
      expect(second.updatedAt, 200);
    });

    test('snapshot lists the tracks of one root', () async {
      final other = (await db.addRoots(['/o'], now: 1)).single;
      await db.upsertTracks([
        track(rootId, '/m/a.mp3', mtimeMs: 7),
        track(other, '/o/b.mp3'),
      ]);
      final snapshot = await db.trackSnapshot(rootId);
      expect(snapshot, hasLength(1));
      expect(snapshot.single.path, '/m/a.mp3');
      expect(snapshot.single.mtimeMs, 7);
      expect(snapshot.single.sizeBytes, 10);
    });

    test('deletes by id across chunks', () async {
      final count = deleteChunkSize * 2 + 3;
      await db.upsertTracks([
        for (var i = 0; i < count; i++) track(rootId, '/m/$i.mp3'),
      ]);
      final ids = (await db.trackSnapshot(rootId)).map((s) => s.id).toList();
      await db.deleteTracksById(ids.take(count - 1));
      expect(await db.trackSnapshot(rootId), hasLength(1));
      await db.deleteTracksById([]);
      expect(await db.trackSnapshot(rootId), hasLength(1));
    });

    test('deleting a root removes its tracks (raw SQL)', () async {
      await db.upsertTracks([track(rootId, '/m/a.mp3')]);
      await db.customStatement('DELETE FROM library_roots WHERE id = $rootId');
      expect(await db.select(db.tracks).get(), isEmpty);
    });

    test('songs order by title ignoring case, then id', () async {
      await db.upsertTracks([
        track(rootId, '/m/1.mp3', title: 'beta'),
        track(rootId, '/m/2.mp3', title: 'Alpha'),
        track(rootId, '/m/3.mp3', title: 'alpha'),
      ]);
      final items = await db.songs();
      expect(items.map((i) => i.path), ['/m/2.mp3', '/m/3.mp3', '/m/1.mp3']);
    });
  });

  group('title order', () {
    test('the title order is served by the title_sort index', () async {
      final plan = await db
          .customSelect('EXPLAIN QUERY PLAN ${songsSql(SongOrder.title)}')
          .get();
      final details = plan.map((r) => r.read<String>('detail')).join('\n');

      expect(details, contains('tracks_title_sort'));
      expect(details, isNot(contains('TEMP B-TREE')));
    });

    test('snapshots flag rows whose tags failed to read for a reason that may pass', () async {
      final id = (await db.addRoots(['/m'], now: 1)).single;
      await db.upsertTracks([
        track(id, '/m/ok.mp3'),
        track(id, '/m/bad.mp3').copyWith(scanError: const Value('x')),
        track(
          id,
          '/m/corrupt.mp3',
        ).copyWith(scanError: const Value('permanent:v1:unsupported')),
        track(
          id,
          '/m/old.mp3',
        ).copyWith(scanError: const Value('permanent:unsupported')),
        track(
          id,
          '/m/older.mp3',
        ).copyWith(scanError: const Value('permanent:v0:unsupported')),
      ]);

      final byPath = {
        for (final t in await db.trackSnapshot(id)) t.path: t.hasScanError,
      };

      expect(byPath, {
        '/m/ok.mp3': false,
        '/m/bad.mp3': true,
        '/m/corrupt.mp3': false,
        '/m/old.mp3': true,
        '/m/older.mp3': true,
      });
    });
  });

  test('a new database has empty cover columns by default', () async {
    final rootId = (await db.addRoots(['/m'], now: 1)).single;
    await db.upsertTracks([track(rootId, '/m/a.flac')]);
    final row = await db.select(db.tracks).getSingle();
    expect(row.coverKey, isNull);
    expect(row.coverScanVersion, 0);
    expect(db.schemaVersion, 5);
  });

  group('cover keys', () {
    Future<void> withCover(int rootId, String path, String? key) =>
        db.upsertTracks([
          track(rootId, path).copyWith(
            coverKey: Value(key),
            coverScanVersion: const Value(coverScanVersion),
          ),
        ]);

    test('lists the distinct keys in use', () async {
      final rootId = (await db.addRoots(['/m'], now: 1)).single;
      await withCover(rootId, '/m/a', 'aa/a.jpg');
      await withCover(rootId, '/m/b', 'aa/a.jpg');
      await withCover(rootId, '/m/c', 'bb/b.jpg');
      await withCover(rootId, '/m/d', null);
      expect(await db.coverKeysInUse(), {'aa/a.jpg', 'bb/b.jpg'});
    });

    test('reset clears the key and the stamp of matching tracks', () async {
      final rootId = (await db.addRoots(['/m'], now: 1)).single;
      final keys = [for (var i = 0; i < 1200; i++) 'k/$i.jpg'];
      await db.upsertTracks([
        for (final (i, key) in keys.indexed)
          track(rootId, '/m/$i').copyWith(
            coverKey: Value(key),
            coverScanVersion: const Value(coverScanVersion),
          ),
      ]);
      await withCover(rootId, '/m/keep', 'keep.jpg');

      await db.resetCoverScan(keys);

      expect(await db.coverKeysInUse(), {'keep.jpg'});
      final rows = await db.select(db.tracks).get();
      final kept = rows.singleWhere((t) => t.path == '/m/keep');
      expect(kept.coverScanVersion, coverScanVersion);
      expect(
        rows.where((t) => t.coverScanVersion == 0),
        hasLength(keys.length),
      );
    });
  });

  group('cover lookups', () {
    late int rootId;
    setUp(() async => rootId = (await db.addRoots(['/m'], now: 1)).single);

    Future<void> add(String path, {int version = 0, int? root}) =>
        db.upsertTracks([
          track(
            root ?? rootId,
            path,
          ).copyWith(coverScanVersion: Value(version)),
        ]);
    Future<List<String>> paths(
      List<int> roots, {
      String? after,
      Set<int> excluding = const {},
      int limit = 10,
    }) async => [
      for (final (_, path) in await db.tracksNeedingCover(
        roots,
        after: after,
        excluding: excluding,
        limit: limit,
      ))
        path,
    ];

    test('lists tracks under older rules, by path, after a cursor', () async {
      final other = (await db.addRoots(['/o'], now: 1)).single;
      await add('/m/c');
      await add('/m/a');
      await add('/m/b', version: coverScanVersion);
      await add('/m/d');
      await add('/o/x', root: other);

      expect(await paths([rootId]), ['/m/a', '/m/c', '/m/d']);
      expect(await paths([rootId], after: '/m/a'), ['/m/c', '/m/d']);
      expect(await paths([rootId], limit: 2), ['/m/a', '/m/c']);
      expect(await paths([rootId, other], after: '/m/d'), ['/o/x']);
      expect(await paths([]), isEmpty);
    });

    test('passes over excluded ids without counting them', () async {
      for (var i = 0; i < 10; i++) {
        await add('/m/$i');
      }
      final ids = {
        for (final (id, path) in await db.tracksNeedingCover([
          rootId,
        ], limit: 10))
          if (path.compareTo('/m/6') < 0) id,
      };
      expect(await paths([rootId], excluding: ids, limit: 3), [
        '/m/6',
        '/m/7',
        '/m/8',
      ]);
    });

    test('writes keys and stamps without notifying watchers', () async {
      await add('/m/a');
      await add('/m/b');
      await add('/m/c', version: coverScanVersion);
      final rows = {
        for (final row in await db.select(db.tracks).get()) row.path: row.id,
      };
      var updates = 0;
      final sub = db
          .tableUpdates(TableUpdateQuery.onTable(db.tracks))
          .listen((_) => updates++);
      addTearDown(sub.cancel);

      await db.writeCovers([
        (rows['/m/a']!, 'aa/a.jpg'),
        (rows['/m/b']!, null),
        // Already stamped: left alone.
        (rows['/m/c']!, 'cc/c.jpg'),
      ]);
      await pumpEventQueue();

      final stored = {
        for (final row in await db.select(db.tracks).get())
          row.path: (row.coverKey, row.coverScanVersion),
      };
      expect(stored, {
        '/m/a': ('aa/a.jpg', coverScanVersion),
        '/m/b': (null, coverScanVersion),
        '/m/c': (null, coverScanVersion),
      });
      expect(updates, 0);
    });
  });
}
