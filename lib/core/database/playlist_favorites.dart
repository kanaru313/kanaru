import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show setEquals;

import 'library_database.dart';
import 'playlist_writes.dart';

/// `playlists.kind` of the Favorites playlist (invariant 8 in
/// `user_data_tables.dart`).
const favoritesKind = 'favorites';

/// `playlists.kind` of a saved queue (invariant 8 in `user_data_tables.dart`):
/// kept for queue history, never listed with the playlists.
const queueKind = 'queue';

/// What `playlists.name` holds for the Favorites playlist. Only a fallback
/// for tools that read the database directly: the app always shows the
/// localized `navFavorites` instead.
const favoritesStoredName = 'Favorites';

/// The Favorites playlist: an ordinary playlist row with
/// `kind = 'favorites'`, created the first time a song is liked.
extension PlaylistFavorites on LibraryDatabase {
  /// The id of the Favorites playlist, or null before the first like. Never
  /// creates it.
  Future<int?> favoritesPlaylistId() => customSelect(
    'SELECT id FROM playlists WHERE kind = ?1',
    variables: [Variable.withString(favoritesKind)],
    readsFrom: {playlists},
  ).map((row) => row.read<int>('id')).getSingleOrNull();

  /// The id of the Favorites playlist, creating it when there is none.
  ///
  /// Reads first and writes only when the row is missing: an
  /// `INSERT OR IGNORE` that ignores still tells drift that `playlists`
  /// changed, which would reload every open playlist page on each like. The
  /// create path follows invariant 8 (`INSERT OR IGNORE`, then `SELECT id`),
  /// so two concurrent calls still end with one row.
  Future<int> ensureFavoritesPlaylist({required int now}) =>
      transaction(() async {
        final existing = await favoritesPlaylistId();
        if (existing != null) return existing;
        await into(playlists).insert(
          PlaylistsCompanion.insert(
            name: favoritesStoredName,
            createdAt: now,
            kind: const Value(favoritesKind),
          ),
          mode: InsertMode.insertOrIgnore,
        );
        return (await favoritesPlaylistId())!;
      });

  /// Whether [path] is in Favorites, read once. For callers that cannot rely
  /// on a live stream (a stream with no listener is paused and its last
  /// value may be stale).
  Future<bool> isFavorite(String path) async {
    final row = await customSelect(
      'SELECT 1 FROM playlist_entries e '
      'JOIN playlists p ON p.id = e.playlist_id '
      'WHERE p.kind = ?1 AND e.path = ?2 LIMIT 1',
      variables: [
        Variable.withString(favoritesKind),
        Variable.withString(path),
      ],
      readsFrom: {playlists, playlistEntries},
    ).getSingleOrNull();
    return row != null;
  }

  /// Puts [path] in Favorites ([favorite] true) or takes it out (false).
  ///
  /// Sets the wanted state rather than toggling, so a repeated call is a
  /// no-op and writes nothing. Adding appends at the end (creating the
  /// playlist on the first like). Removing deletes every entry of [path],
  /// duplicates included, and never creates the playlist. [path] is not
  /// checked against the library: callers decide which songs may be liked.
  /// [now] is epoch milliseconds.
  Future<void> setFavorite(
    String path, {
    required bool favorite,
    required int now,
  }) => transaction(() async {
    if (await isFavorite(path) == favorite) return;
    if (favorite) {
      final id = await ensureFavoritesPlaylist(now: now);
      await addMissingToPlaylist(id, [path]);
      return;
    }
    final id = await favoritesPlaylistId();
    if (id == null) return;
    final rows = await customSelect(
      'SELECT id FROM playlist_entries WHERE playlist_id = ?1 AND path = ?2',
      variables: [Variable.withInt(id), Variable.withString(path)],
      readsFrom: {playlistEntries},
    ).get();
    await removePlaylistEntries(id, {
      for (final row in rows) row.read<int>('id'),
    });
  });

  /// The paths in Favorites; emits only when the set changes. Re-queries on
  /// writes to `playlists` and `playlist_entries` only, never on scans.
  Stream<Set<String>> watchFavoritePaths() =>
      customSelect(
            'SELECT e.path FROM playlist_entries e '
            'JOIN playlists p ON p.id = e.playlist_id WHERE p.kind = ?1',
            variables: [Variable.withString(favoritesKind)],
            readsFrom: {playlists, playlistEntries},
          )
          .map((row) => row.read<String>('path'))
          .watch()
          .map((paths) => paths.toSet())
          .distinct(setEquals);

  /// The id of the Favorites playlist as it comes and goes; null before the
  /// first like.
  Stream<int?> watchFavoritesPlaylistId() => customSelect(
    'SELECT id FROM playlists WHERE kind = ?1',
    variables: [Variable.withString(favoritesKind)],
    readsFrom: {playlists},
  ).map((row) => row.read<int>('id')).watchSingleOrNull().distinct();
}
