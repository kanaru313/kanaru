import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/core/database/playlist_write_helpers.dart';

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('counts distinct paths of the batch per playlist', () async {
    final a = await db.createPlaylist('A', now: 1, paths: ['/a', '/a', '/c']);
    await db.createPlaylist('B', now: 1, paths: ['/z']);

    final counts = await db.playlistOverlapCounts(['/a', '/a', '/b', '/c']);

    expect(counts, {a: 2});
  });

  test('Favorites and saved queues are never reported', () async {
    final fav = await db.ensureFavoritesPlaylist(now: 1);
    await db.addMissingToPlaylist(fav, ['/a']);
    final q = await db
        .into(db.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: 'Q',
            createdAt: 1,
            kind: const Value(queueKind),
          ),
        );
    await db.appendPlaylistPaths(q, ['/a'], start: 0);

    expect(await db.playlistOverlapCounts(['/a']), isEmpty);
  });

  test('playlistIds limits the playlists looked at', () async {
    final a = await db.createPlaylist('A', now: 1, paths: ['/a']);
    final b = await db.createPlaylist('B', now: 1, paths: ['/a']);

    expect(await db.playlistOverlapCounts(['/a'], playlistIds: [b]), {b: 1});
    expect(await db.playlistOverlapCounts(['/a'], playlistIds: []), isEmpty);
    expect(await db.playlistOverlapCounts([]), isEmpty);
    expect(a, isNot(b));
  });

  test('5000 paths hit no variable limit', () async {
    final paths = [for (var i = 0; i < 5000; i++) '/m/$i'];
    final a = await db.createPlaylist('A', now: 1, paths: paths);

    expect(await db.playlistOverlapCounts(paths), {a: 5000});
  });
}
