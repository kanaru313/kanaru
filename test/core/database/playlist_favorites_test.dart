import 'package:drift/drift.dart' show TableUpdateQuery, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/database/playlist_queries.dart';

import 'library_database_test.dart' show track;

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> playlistCount() async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM playlists').getSingle())
          .read<int>('n');

  Future<List<String>> favoritePaths(int id) async => [
    for (final e in (await db.playlistPage(id))!.entries) e.path,
  ];

  /// Counts table update events while [body] runs.
  Future<int> updatesDuring(Future<void> Function() body) async {
    var events = 0;
    final sub = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([db.playlists, db.playlistEntries]),
        )
        .listen((_) => events++);
    await body();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    return events;
  }

  group('ensure', () {
    test('creates one row and returns the same id every time', () async {
      expect(await db.favoritesPlaylistId(), isNull);

      final a = await db.ensureFavoritesPlaylist(now: 1);
      final b = await db.ensureFavoritesPlaylist(now: 2);

      expect(b, a);
      expect(await db.favoritesPlaylistId(), a);
      expect(await playlistCount(), 1);
      final row = await (db.select(db.playlists)).getSingle();
      expect(row.kind, favoritesKind);
      expect(row.name, favoritesStoredName);
    });

    test('concurrent calls end with one row', () async {
      final ids = await Future.wait([
        for (var i = 0; i < 5; i++) db.ensureFavoritesPlaylist(now: i),
      ]);

      expect(ids.toSet(), hasLength(1));
      expect(await playlistCount(), 1);
    });

    test('writes nothing when the playlist exists', () async {
      await db.ensureFavoritesPlaylist(now: 1);

      final events = await updatesDuring(
        () => db.ensureFavoritesPlaylist(now: 2),
      );

      expect(events, 0);
    });
  });

  group('setFavorite', () {
    test('adds once and a repeated add writes nothing', () async {
      await db.setFavorite('/m/a', favorite: true, now: 1);
      final id = (await db.favoritesPlaylistId())!;

      final events = await updatesDuring(
        () => db.setFavorite('/m/a', favorite: true, now: 2),
      );

      expect(events, 0);
      expect(await favoritePaths(id), ['/m/a']);
      expect(await db.isFavorite('/m/a'), isTrue);
      expect(await db.isFavorite('/m/b'), isFalse);
    });

    test('appends new likes at the end', () async {
      await db.setFavorite('/m/a', favorite: true, now: 1);
      await db.setFavorite('/m/b', favorite: true, now: 1);
      await db.setFavorite('/m/a', favorite: false, now: 1);
      await db.setFavorite('/m/a', favorite: true, now: 1);

      expect(await favoritePaths((await db.favoritesPlaylistId())!), [
        '/m/b',
        '/m/a',
      ]);
    });

    test('removing before the first like creates nothing', () async {
      final events = await updatesDuring(
        () => db.setFavorite('/m/a', favorite: false, now: 1),
      );

      expect(events, 0);
      expect(await playlistCount(), 0);
    });

    test('removing deletes every copy and closes the gaps', () async {
      final id = await db.ensureFavoritesPlaylist(now: 1);
      for (final (path, position) in [('/m/a', 0), ('/m/b', 1), ('/m/a', 2)]) {
        await db.customStatement(
          'INSERT INTO playlist_entries (playlist_id, path, position) '
          'VALUES (?, ?, ?)',
          [id, path, position],
        );
      }

      await db.setFavorite('/m/a', favorite: false, now: 1);

      final rows = await db
          .customSelect(
            'SELECT path, position FROM playlist_entries '
            'WHERE playlist_id = ?1',
            variables: [Variable.withInt(id)],
          )
          .get();
      expect(
        rows.map((r) => (r.read<String>('path'), r.read<int>('position'))),
        [('/m/b', 0)],
      );
      expect(await db.isFavorite('/m/a'), isFalse);
    });

    test('ignores the entries of other playlists', () async {
      final other = await db.createPlaylist('Mix', now: 1, paths: ['/m/a']);
      expect(await db.isFavorite('/m/a'), isFalse);

      await db.setFavorite('/m/a', favorite: true, now: 1);
      await db.setFavorite('/m/a', favorite: false, now: 1);

      expect((await db.playlistPage(other))!.entries.single.path, '/m/a');
    });
  });

  group('rename and delete', () {
    test('never touch the Favorites playlist', () async {
      final id = await db.ensureFavoritesPlaylist(now: 1);
      await db.setFavorite('/m/a', favorite: true, now: 1);

      await db.renamePlaylist(id, 'Renamed');
      await db.deletePlaylist(id);

      final summary = (await db.playlistSummary(id))!;
      expect(summary.name, favoritesStoredName);
      expect(summary.isFavorites, isTrue);
      expect(summary.entryCount, 1);
    });

    test('still work on ordinary playlists (NULL kind)', () async {
      await db.ensureFavoritesPlaylist(now: 1);
      final id = await db.createPlaylist('Mix', now: 1);

      await db.renamePlaylist(id, 'Renamed');
      expect((await db.playlistSummary(id))!.name, 'Renamed');

      await db.deletePlaylist(id);
      expect(await db.playlistSummary(id), isNull);
    });
  });

  group('lists', () {
    test('leave out Favorites and keep other kinds', () async {
      final fav = await db.ensureFavoritesPlaylist(now: 1);
      final plain = await db.createPlaylist('Mix', now: 2);
      await db.customStatement(
        "INSERT INTO playlists (name, created_at, kind) VALUES ('Q', 3, 'queue')",
      );

      final summaries = await db.watchPlaylistSummaries().first;
      final cards = await db.playlistCards();

      expect(summaries.map((s) => s.name), ['Q', 'Mix']);
      expect(cards.map((c) => c.playlist.name), ['Q', 'Mix']);
      expect(summaries.any((s) => s.isFavorites), isFalse);
      expect((await db.playlistSummary(plain))!.isFavorites, isFalse);
      expect((await db.playlistSummary(fav))!.isFavorites, isTrue);
    });
  });

  group('streams', () {
    test('favorite paths follow likes and ignore scans', () async {
      final root = (await db.addRoots(['/m'], now: 1)).single;
      final events = <Set<String>>[];
      final sub = db.watchFavoritePaths().listen(events.add);
      addTearDown(sub.cancel);
      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 50));

      await settle();
      await db.setFavorite('/m/a', favorite: true, now: 1);
      await settle();
      await db.upsertTracks([track(root, '/m/a'), track(root, '/m/b')]);
      await settle();
      await db.createPlaylist('Mix', now: 1, paths: ['/m/b']);
      await settle();
      await db.setFavorite('/m/a', favorite: false, now: 1);
      await settle();

      expect(events, [
        <String>{},
        {'/m/a'},
        <String>{},
      ]);
    });

    test('favorites id appears on the first like', () async {
      final events = <int?>[];
      final sub = db.watchFavoritesPlaylistId().listen(events.add);
      addTearDown(sub.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await db.setFavorite('/m/a', favorite: true, now: 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, [null, await db.favoritesPlaylistId()]);
    });
  });
}
