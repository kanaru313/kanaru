import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';

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

    test('watchRoots emits the current roots', () async {
      await db.addRoots(['/a'], now: 1);
      expect((await db.watchRoots().first).single.path, '/a');
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

    test('snapshots flag rows whose tags failed to read', () async {
      final id = (await db.addRoots(['/m'], now: 1)).single;
      await db.upsertTracks([
        track(id, '/m/ok.mp3'),
        track(id, '/m/bad.mp3').copyWith(scanError: const Value('x')),
      ]);

      final byPath = {
        for (final t in await db.trackSnapshot(id)) t.path: t.hasScanError,
      };

      expect(byPath, {'/m/ok.mp3': false, '/m/bad.mp3': true});
    });
  });

  test('a new database has empty cover columns by default', () async {
    final rootId = (await db.addRoots(['/m'], now: 1)).single;
    await db.upsertTracks([track(rootId, '/m/a.flac')]);
    final row = await db.select(db.tracks).getSingle();
    expect(row.coverKey, isNull);
    expect(row.coverScanVersion, 0);
    expect(db.schemaVersion, 3);
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
      final snapshot = await db.trackSnapshot(rootId);
      final kept = snapshot.singleWhere((t) => t.path == '/m/keep');
      expect(kept.coverScanVersion, coverScanVersion);
      expect(
        snapshot.where((t) => t.coverScanVersion == 0),
        hasLength(keys.length),
      );
    });
  });
}
