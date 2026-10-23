import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/database/playlist_queries.dart';

/// Saved queues (`kind = 'queue'`) share the playlist tables but never show
/// up where playlists are listed.
void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Inserts a playlist row with [kind] as written, NULL included.
  Future<int> playlistOfKind(String name, String? kind, {int now = 1}) => db
      .into(db.playlists)
      .insert(
        PlaylistsCompanion.insert(
          name: name,
          createdAt: now,
          kind: Value(kind),
        ),
      );

  Future<List<String>> summaryNames() async => [
    for (final s in await db.watchPlaylistSummaries().first) s.name,
  ];

  Future<List<String>> cardNames() async => [
    for (final c in await db.playlistCards()) c.playlist.name,
  ];

  test('saved queues are left out of both lists', () async {
    await playlistOfKind('Plain', null, now: 1);
    await playlistOfKind('Saved queue', queueKind, now: 2);
    await playlistOfKind('Another queue', queueKind, now: 3);

    expect(await summaryNames(), ['Plain']);
    expect(await cardNames(), ['Plain']);
  });

  test('ordinary playlists and unknown kinds stay listed', () async {
    await playlistOfKind('Plain', null, now: 1);
    await playlistOfKind('Other', 'other', now: 2);
    await playlistOfKind('Saved queue', queueKind, now: 3);

    expect(await summaryNames(), ['Other', 'Plain']);
    expect(await cardNames(), ['Other', 'Plain']);
  });

  test('Favorites stays out next to saved queues', () async {
    await playlistOfKind('Plain', null, now: 1);
    await db.ensureFavoritesPlaylist(now: 2);
    await playlistOfKind('Saved queue', queueKind, now: 3);

    expect(await summaryNames(), ['Plain']);
    expect(await cardNames(), ['Plain']);
  });

  test('a saved queue is still readable by id', () async {
    final id = await playlistOfKind('Saved queue', queueKind);

    final summary = await db.playlistSummary(id);

    expect(summary?.name, 'Saved queue');
    expect(summary?.isFavorites, isFalse);
  });
}
