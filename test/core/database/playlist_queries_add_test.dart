import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/playlist_queries.dart';

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<String>> pathsOf(int id) async => [
    for (final e in (await db.playlistPage(id))!.entries) e.path,
  ];

  Future<List<int>> positionsOf(int id) async => [
    for (final e in await (db.select(
      db.playlistEntries,
    )..where((e) => e.playlistId.equals(id))).get())
      e.position,
  ]..sort();

  group('add', () {
    test('appends in order after the existing entries', () async {
      final id = await db.createPlaylist('A', now: 1, paths: ['/m/a']);

      final result = await db.addMissingToPlaylist(id, ['/m/b', '/m/c']);

      expect(result, (added: 2, skipped: 0));
      expect(await pathsOf(id), ['/m/a', '/m/b', '/m/c']);
      expect(await positionsOf(id), [0, 1, 2]);
    });

    test('repeats inside the batch are added once, first kept', () async {
      final id = await db.createPlaylist('A', now: 1);

      final result = await db.addMissingToPlaylist(id, [
        '/m/b',
        '/m/a',
        '/m/b',
        '/m/c',
        '/m/a',
      ]);

      expect(result, (added: 3, skipped: 0));
      expect(await pathsOf(id), ['/m/b', '/m/a', '/m/c']);
    });

    test(
      'paths already in the playlist are skipped and counted once',
      () async {
        final id = await db.createPlaylist(
          'A',
          now: 1,
          paths: ['/m/a', '/m/c'],
        );

        final result = await db.addMissingToPlaylist(id, [
          '/m/a',
          '/m/b',
          '/m/a',
          '/m/c',
        ]);

        expect(result, (added: 1, skipped: 2));
        expect(await pathsOf(id), ['/m/a', '/m/c', '/m/b']);
        expect(await positionsOf(id), [0, 1, 2]);
      },
    );

    test('all already there writes nothing and wakes nobody', () async {
      final id = await db.createPlaylist('A', now: 1, paths: ['/m/a', '/m/b']);
      var updates = 0;
      final sub = db
          .tableUpdates(TableUpdateQuery.onTable(db.playlistEntries))
          .listen((_) => updates++);
      addTearDown(sub.cancel);

      final result = await db.addMissingToPlaylist(id, ['/m/b', '/m/a']);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(result, (added: 0, skipped: 2));
      expect(await pathsOf(id), ['/m/a', '/m/b']);
      expect(updates, 0);
    });

    test('duplicates already stored are left as they are', () async {
      final id = await db.createPlaylist('A', now: 1, paths: ['/m/a', '/m/a']);

      final result = await db.addMissingToPlaylist(id, ['/m/a', '/m/b']);

      expect(result, (added: 1, skipped: 1));
      expect(await pathsOf(id), ['/m/a', '/m/a', '/m/b']);
    });

    test('only the target playlist counts as "already there"', () async {
      final a = await db.createPlaylist('A', now: 1, paths: ['/m/a']);
      final b = await db.createPlaylist('B', now: 2);

      expect(await db.addMissingToPlaylist(b, ['/m/a']), (
        added: 1,
        skipped: 0,
      ));
      expect(await pathsOf(a), ['/m/a']);
      expect(await pathsOf(b), ['/m/a']);
    });

    test('adding nothing writes nothing', () async {
      final id = await db.createPlaylist('A', now: 1);

      expect(await db.addMissingToPlaylist(id, const []), (
        added: 0,
        skipped: 0,
      ));
      expect(await db.select(db.playlistEntries).get(), isEmpty);
    });

    test('overlapping adds at the same time store no path twice', () async {
      final id = await db.createPlaylist('A', now: 1);

      final results = await Future.wait([
        db.addMissingToPlaylist(id, ['/m/a', '/m/b']),
        db.addMissingToPlaylist(id, ['/m/b', '/m/c']),
        db.addMissingToPlaylist(id, ['/m/a', '/m/c', '/m/d']),
      ]);

      final stored = await pathsOf(id);
      expect(stored.toSet(), {'/m/a', '/m/b', '/m/c', '/m/d'});
      expect(stored, hasLength(4));
      expect(await positionsOf(id), [0, 1, 2, 3]);
      expect(results.fold<int>(0, (sum, r) => sum + r.added), 4);
    });

    test('thousands of paths fit in one add', () async {
      final all = [for (var i = 0; i < 5000; i++) '/m/song-$i'];
      final id = await db.createPlaylist(
        'A',
        now: 1,
        paths: all.sublist(0, 2000),
      );

      final result = await db.addMissingToPlaylist(id, all);

      expect(result, (added: 3000, skipped: 2000));
      expect(await pathsOf(id), all);
      expect(await positionsOf(id), [for (var i = 0; i < 5000; i++) i]);
    });

    test('a deleted playlist throws and inserts nothing', () async {
      final id = await db.createPlaylist('A', now: 1);
      await db.deletePlaylist(id);

      await expectLater(
        db.addMissingToPlaylist(id, ['/m/a']),
        throwsA(anything),
      );
      expect(await db.select(db.playlistEntries).get(), isEmpty);
    });
  });
}
