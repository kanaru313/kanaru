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

      expect(await pathsOf(a), ['/m/a']);
      expect(await pathsOf(b), ['/m/b']);
      expect(await positionsOf(a), [0]);
      expect(await positionsOf(b), [0]);
    });

    test(
      'another playlist keeps its positions when this one shrinks',
      () async {
        final a = await db.createPlaylist('A', now: 1, paths: ['/m/a', '/m/b']);
        final b = await db.createPlaylist('B', now: 2, paths: ['/m/c', '/m/d']);
        final inA = (await db.playlistPage(a))!.entries;

        await db.removePlaylistEntries(a, {inA.first.entryId});

        expect(await pathsOf(a), ['/m/b']);
        expect(await pathsOf(b), ['/m/c', '/m/d']);
        expect(await positionsOf(b), [0, 1]);
      },
    );

    test('removing the last entry keeps the others in place', () async {
      final id = await db.createPlaylist('A', now: 1, paths: ['/m/a', '/m/b']);
      final entries = (await db.playlistPage(id))!.entries;

      await db.removePlaylistEntries(id, {entries.last.entryId});

      expect(await pathsOf(id), ['/m/a']);
      expect(await positionsOf(id), [0]);
    });

    test(
      'removing everything leaves an empty playlist that restarts at 0',
      () async {
        final id = await db.createPlaylist(
          'A',
          now: 1,
          paths: ['/m/a', '/m/b'],
        );
        final entries = (await db.playlistPage(id))!.entries;

        await db.removePlaylistEntries(id, {
          for (final e in entries) e.entryId,
        });
        expect((await db.playlistSummary(id))!.entryCount, 0);
        await db.addMissingToPlaylist(id, ['/m/c']);

        expect(await pathsOf(id), ['/m/c']);
        expect(await positionsOf(id), [0]);
      },
    );

    test('after moves it still closes the gaps in the shown order', () async {
      final id = await db.createPlaylist(
        'A',
        now: 1,
        paths: ['/m/a', '/m/b', '/m/c', '/m/d', '/m/e'],
      );
      var entries = (await db.playlistPage(id))!.entries;
      await db.movePlaylistEntry(id, entries[4].entryId, 0);
      await db.movePlaylistEntry(id, entries[0].entryId, 3);
      // Now: e b c a d
      entries = (await db.playlistPage(id))!.entries;
      expect(entries.map((e) => e.path), [
        '/m/e',
        '/m/b',
        '/m/c',
        '/m/a',
        '/m/d',
      ]);

      await db.removePlaylistEntries(id, {
        entries[1].entryId,
        entries[3].entryId,
      });

      expect(await pathsOf(id), ['/m/e', '/m/c', '/m/d']);
      expect(await positionsOf(id), [0, 1, 2]);
    });

    test('an unknown playlist or a stale id changes nothing', () async {
      final id = await db.createPlaylist('A', now: 1, paths: ['/m/a', '/m/b']);

      await db.removePlaylistEntries(999, {1, 2});
      await db.removePlaylistEntries(id, {12345});

      expect(await pathsOf(id), ['/m/a', '/m/b']);
      expect(await positionsOf(id), [0, 1]);
    });
  });
}
