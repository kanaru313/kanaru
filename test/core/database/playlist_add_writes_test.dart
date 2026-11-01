import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/database/playlist_queries.dart';

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<String>> pathsOf(int id) async {
    final rows =
        await (db.select(db.playlistEntries)
              ..where((e) => e.playlistId.equals(id))
              ..orderBy([(e) => OrderingTerm.asc(e.position)]))
            .get();
    return [for (final e in rows) e.path];
  }

  Future<List<int>> positionsOf(int id) async => [
    for (final e in await (db.select(
      db.playlistEntries,
    )..where((e) => e.playlistId.equals(id))).get())
      e.position,
  ]..sort();

  Future<int> playlist(String name, [List<String> paths = const []]) =>
      db.createPlaylist(name, now: 1, paths: paths);

  test('appendAll keeps batch repeats and existing copies', () async {
    final id = await playlist('A', ['/a']);

    final out = await db.addToPlaylists(
      paths: ['/a', '/a', '/b'],
      targets: {id: PlaylistAddMode.appendAll},
      now: 2,
    );

    expect(await pathsOf(id), ['/a', '/a', '/a', '/b']);
    expect(await positionsOf(id), [0, 1, 2, 3]);
    expect((out.added, out.skipped, out.removed), (3, 0, 0));
    expect(out.targetCount, 1);
  });

  test('missingOnly matches addMissingToPlaylist', () async {
    final a = await playlist('A', ['/a']);
    final b = await playlist('B', ['/a']);
    final batch = ['/b', '/a', '/b', '/c'];

    final expected = await db.addMissingToPlaylist(b, batch);
    final out = await db.addToPlaylists(
      paths: batch,
      targets: {a: PlaylistAddMode.missingOnly},
      now: 2,
    );

    expect(await pathsOf(a), await pathsOf(b));
    expect((out.added, out.skipped), (expected.added, expected.skipped));
  });

  test('replaceOld drops old copies and appends the batch', () async {
    final id = await playlist('A', ['/a', '/b', '/c', '/a']);

    final out = await db.addToPlaylists(
      paths: ['/a', '/d'],
      targets: {id: PlaylistAddMode.replaceOld},
      now: 2,
    );

    expect(await pathsOf(id), ['/b', '/c', '/a', '/d']);
    expect(await positionsOf(id), [0, 1, 2, 3]);
    expect((out.removed, out.added), (2, 2));
  });

  test('batch with repeats in every mode', () async {
    final x = await playlist('X', ['/a']);
    final y = await playlist('Y', ['/a']);
    final z = await playlist('Z', ['/a']);

    final out = await db.addToPlaylists(
      paths: ['/a', '/a', '/b'],
      targets: {
        x: PlaylistAddMode.appendAll,
        y: PlaylistAddMode.missingOnly,
        z: PlaylistAddMode.replaceOld,
      },
      now: 2,
    );

    expect(await pathsOf(x), ['/a', '/a', '/a', '/b']);
    expect(await pathsOf(y), ['/a', '/b']);
    expect(await pathsOf(z), ['/a', '/a', '/b']);
    expect(await positionsOf(z), [0, 1, 2]);
    expect((out.skipped, out.removed), (1, 1));
  });

  test('each target keeps its own mode', () async {
    final x = await playlist('X', ['/a']);
    final y = await playlist('Y');

    await db.addToPlaylists(
      paths: ['/a', '/a', '/b'],
      targets: {x: PlaylistAddMode.missingOnly, y: PlaylistAddMode.appendAll},
      now: 2,
    );

    expect(await pathsOf(x), ['/a', '/b']);
    expect(await pathsOf(y), ['/a', '/a', '/b']);
  });

  test('targets and new playlists are written together', () async {
    final a = await playlist('A');

    final out = await db.addToPlaylists(
      paths: ['/a', '/b'],
      targets: {a: PlaylistAddMode.appendAll},
      newNames: ['  N1 ', 'N2'],
      now: 5,
    );

    final all = await db.select(db.playlists).get();
    expect([for (final p in all) p.name], ['A', 'N1', 'N2']);
    for (final p in all) {
      expect(await pathsOf(p.id), ['/a', '/b']);
    }
    expect(out.created, ['N1', 'N2']);
    expect((out.added, out.targetCount), (6, 3));
  });

  test('a blank new name writes nothing', () async {
    final a = await playlist('A');

    await expectLater(
      db.addToPlaylists(
        paths: ['/a'],
        targets: {a: PlaylistAddMode.appendAll},
        newNames: ['Ok', '  '],
        now: 2,
      ),
      throwsArgumentError,
    );

    expect((await db.select(db.playlists).get()).length, 1);
    expect(await pathsOf(a), isEmpty);
  });

  test('Favorites never gets a duplicate', () async {
    final fav = await db.ensureFavoritesPlaylist(now: 1);
    await db.addMissingToPlaylist(fav, ['/a']);

    final out = await db.addToPlaylists(
      paths: ['/a', '/b', '/b'],
      targets: {fav: PlaylistAddMode.appendAll},
      now: 2,
    );

    expect(await pathsOf(fav), ['/a', '/b']);
    expect((out.added, out.skipped), (1, 1));
  });

  test('a target that is gone is skipped', () async {
    final a = await playlist('A');

    final out = await db.addToPlaylists(
      paths: ['/a'],
      targets: {a: PlaylistAddMode.appendAll, 999: PlaylistAddMode.appendAll},
      now: 2,
    );

    expect(await pathsOf(a), ['/a']);
    expect((out.gone, out.targetCount), (1, 1));
  });

  test('empty paths write nothing', () async {
    final a = await playlist('A');

    final out = await db.addToPlaylists(
      paths: [],
      targets: {a: PlaylistAddMode.appendAll},
      newNames: ['N'],
      now: 2,
    );

    expect(out.targetCount, 0);
    expect((await db.select(db.playlists).get()).length, 1);
  });

  test('watchers see one emission per call', () async {
    final a = await playlist('A');
    final b = await playlist('B');
    final emissions = <int>[];
    final sub = db.watchPlaylistSummaries().listen(
      (rows) => emissions.add(rows.fold(0, (int n, r) => n + r.entryCount)),
    );
    await pumpEventQueue();
    emissions.clear();

    await db.addToPlaylists(
      paths: ['/a', '/b'],
      targets: {a: PlaylistAddMode.appendAll, b: PlaylistAddMode.appendAll},
      newNames: ['N'],
      now: 2,
    );
    await pumpEventQueue();
    await sub.cancel();

    expect(emissions, [6]);
  });

  test(
    'Favorites with replaceOld stays duplicate-free, removes nothing',
    () async {
      final fav = await db.ensureFavoritesPlaylist(now: 1);
      await db.addMissingToPlaylist(fav, ['/a']);

      final out = await db.addToPlaylists(
        paths: ['/a', '/b'],
        targets: {fav: PlaylistAddMode.replaceOld},
        now: 2,
      );

      expect(await pathsOf(fav), ['/a', '/b']);
      expect(out.removed, 0);
    },
  );

  test('replaceOld with a large batch', () async {
    final paths = [for (var i = 0; i < 5000; i++) '/m/$i'];
    final id = await playlist('A', ['/x', ...paths.take(10)]);

    final out = await db.addToPlaylists(
      paths: paths,
      targets: {id: PlaylistAddMode.replaceOld},
      now: 2,
    );

    expect(out.removed, 10);
    expect((await pathsOf(id)).length, 5001);
    expect(await positionsOf(id), [for (var i = 0; i < 5001; i++) i]);
  });

  test('a failure on a later target rolls everything back', () async {
    final a = await playlist('A', ['/keep']);
    final b = await playlist('B');
    await db.customStatement(
      "CREATE TEMP TRIGGER fail_one BEFORE INSERT ON playlist_entries "
      "WHEN NEW.playlist_id = $b "
      "BEGIN SELECT RAISE(ABORT, 'boom'); END",
    );

    await expectLater(
      db.addToPlaylists(
        paths: ['/a'],
        targets: {a: PlaylistAddMode.appendAll, b: PlaylistAddMode.appendAll},
        newNames: ['N'],
        now: 2,
      ),
      throwsA(anything),
    );

    expect((await db.select(db.playlists).get()).length, 2);
    expect(await pathsOf(a), ['/keep']);
    expect(await pathsOf(b), isEmpty);
  });
}
