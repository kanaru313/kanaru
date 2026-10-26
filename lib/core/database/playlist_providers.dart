import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_startup.dart';
import 'playlist_favorites.dart';
import 'playlist_queries.dart';
import 'playlist_rows.dart';

/// Every listed playlist (not Favorites, not saved queues), newest first;
/// empty without a library. Used only by the add-to-playlist picker (the
/// playlists page reads `playlistCardsProvider`). Not auto-disposed, so the
/// list is already loaded when the picker opens.
final playlistSummariesProvider = StreamProvider<List<PlaylistSummary>>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  return db == null ? Stream.value(const []) : db.watchPlaylistSummaries();
});

/// The paths in Favorites; empty without a library. Every heart button reads
/// it. Not auto-disposed: hearts come and go with the player bar and Now
/// Playing, and the set is small.
final favoritePathsProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  return db == null ? Stream.value(const {}) : db.watchFavoritePaths();
});

/// The id of the Favorites playlist, null before the first like or without a
/// library.
final favoritesPlaylistIdProvider = StreamProvider<int?>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  return db == null ? Stream.value(null) : db.watchFavoritesPlaylistId();
});
