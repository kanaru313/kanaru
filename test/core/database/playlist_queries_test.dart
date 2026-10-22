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

  group('create, rename, delete', () {
    test('a new playlist has no entries', () async {
      final id = await db.createPlaylist('Mix', now: 5);

      final summary = (await db.playlistSummary(id))!;
      expect(summary.name, 'Mix');
      expect(summary.createdAt, 5);
      expect(summary.entryCount, 0);
    });

    test('initial paths are stored at positions 0..n-1', () async {
      final id = await db.createPlaylist(
        'Mix',
        now: 1,
        paths: ['/m/a', '/m/b', '/m/c'],
      );

      expect((await db.playlistSummary(id))!.entryCount, 3);
      expect(await positionsOf(id), [0, 1, 2]);
      expect(await pathsOf(id), ['/m/a', '/m/b', '/m/c']);
    });

    test('a blank name is rejected and nothing is stored', () async {
      await expectLater(
        db.createPlaylist('  ', now: 1, paths: ['/m/a']),
        throwsArgumentError,
      );
      expect(await db.select(db.playlists).get(), isEmpty);
      expect(await db.select(db.playlistEntries).get(), isEmpty);
    });

    test('rename trims; a blank name is rejected', () async {
      final id = await db.createPlaylist('Mix', now: 1);

      await db.renamePlaylist(id, '  Road trip ');
      expect((await db.playlistSummary(id))!.name, 'Road trip');

      await expectLater(db.renamePlaylist(id, ' '), throwsArgumentError);
      expect((await db.playlistSummary(id))!.name, 'Road trip');
    });

    test('delete removes its entries and leaves other playlists', () async {
      final a = await db.createPlaylist('A', now: 1, paths: ['/m/a', '/m/b']);
      final b = await db.createPlaylist('B', now: 2, paths: ['/m/c']);

      await db.deletePlaylist(a);

      expect(await db.playlistSummary(a), isNull);
      expect(await db.playlistPage(a), isNull);
      final left = await db.select(db.playlistEntries).get();
      expect(left.map((e) => e.playlistId), [b]);
    });
  });

  group('add', () {
    test('appends in order after the existing entries', () async {
      final id = await db.createPlaylist('A', now: 1, paths: ['/m/a']);

      expect(await db.addToPlaylist(id, ['/m/b', '/m/c']), 2);

      expect(await pathsOf(id), ['/m/a', '/m/b', '/m/c']);
      expect(await positionsOf(id), [0, 1, 2]);
    });

    test(
      'the same path twice makes two entries; pathsAmong lists it once',
      () async {
        final id = await db.createPlaylist('A', now: 1);
        await db.addToPlaylist(id, ['/m/a']);
        await db.addToPlaylist(id, ['/m/a']);

        final ids = [
          for (final e in (await db.playlistPage(id))!.entries) e.entryId,
        ];
        expect(ids.toSet(), hasLength(2));
        expect(await db.playlistPathsAmong(id, ['/m/a', '/m/z', '/m/a']), {
          '/m/a',
        });
        expect(await db.playlistPathsAmong(id, const []), isEmpty);
      },
    );

    test('adding nothing writes nothing', () async {
      final id = await db.createPlaylist('A', now: 1);

      expect(await db.addToPlaylist(id, const []), 0);
      expect(await db.select(db.playlistEntries).get(), isEmpty);
    });

    test('a deleted playlist throws and inserts nothing', () async {
      final id = await db.createPlaylist('A', now: 1);
      await db.deletePlaylist(id);

      await expectLater(db.addToPlaylist(id, ['/m/a']), throwsA(anything));
      expect(await db.select(db.playlistEntries).get(), isEmpty);
    });
  });

  group('remove', () {
    test('closes the gaps and keeps the order', () async {
      final id = await db.createPlaylist(
        'A',
        now: 1,
        paths: ['/m/a', '/m/b', '/m/c', '/m/d'],
      );
      final entries = (await db.playlistPage(id))!.entries;

      await db.removePlaylistEntries(id, {
        entries[0].entryId,
        entries[2].entryId,
      });

      expect(await pathsOf(id), ['/m/b', '/m/d']);
      expect(await positionsOf(id), [0, 1]);
    });

    test('ignores entries of another playlist', () async {
      final a = await db.createPlaylist('A', now: 1, paths: ['/m/a']);
      final b = await db.createPlaylist('B', now: 2, paths: ['/m/b']);
      final inB = (await db.playlistPage(b))!.entries.single.entryId;

      await db.removePlaylistEntries(a, {inB});

      expect(await pathsOf(b), ['/m/b']);
    });
  });
}
