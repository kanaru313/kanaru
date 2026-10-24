import 'package:drift/drift.dart';

import 'library_database.dart';
import 'playlist_favorites.dart';
import 'playlist_page_shared.dart';
import 'playlist_rows.dart';

export 'playlist_writes.dart';

const _summarySql = '''
SELECT p.id, p.name, p.created_at, p.kind,
  (SELECT COUNT(*) FROM playlist_entries e WHERE e.playlist_id = p.id) AS n
FROM playlists p''';

/// Lists leave out the Favorites playlist, which has its own page and nav
/// entry, and saved queues. Ordinary playlists, whose kind is NULL, are kept
/// by `IS NULL` (`NOT IN` alone gives NULL for them and would drop them), and
/// so is any other kind (invariant 8).
const _listed =
    " WHERE (p.kind IS NULL OR p.kind NOT IN ('$favoritesKind', '$queueKind'))";

const _newestFirst = ' ORDER BY p.created_at DESC, p.id DESC';

/// Playlist reads. Writes are in `playlist_writes.dart`.
extension PlaylistQueries on LibraryDatabase {
  /// Every playlist but Favorites and saved queues, newest first, with its
  /// entry count. Re-queries on writes to `playlists` and `playlist_entries`
  /// only, never on scans, and emits only when the result changed (a reorder
  /// does not change it).
  Stream<List<PlaylistSummary>> watchPlaylistSummaries() => customSelect(
    _summarySql + _listed + _newestFirst,
    readsFrom: {playlists, playlistEntries},
  ).map(_summary).watch().distinct(samePlaylistSummaries);

  /// One playlist with its count, or null when it does not exist. Favorites
  /// included (see [PlaylistSummary.isFavorites]).
  Future<PlaylistSummary?> playlistSummary(int id) => customSelect(
    '$_summarySql WHERE p.id = ?1',
    variables: [Variable.withInt(id)],
    readsFrom: {playlists, playlistEntries},
  ).map(_summary).getSingleOrNull();

  /// Summaries with their collage keys, Favorites and saved queues left out.
  /// Reads `tracks`, so callers wrap it in `throttledTracksQuery`.
  Future<List<PlaylistCard>> playlistCards() => transaction(() async {
    final summaries = await customSelect(_summarySql + _listed + _newestFirst)
        .map(_summary)
        .get();
    return [
      for (final playlist in summaries)
        PlaylistCard(playlist, await playlistCollageKeys(playlist.id)),
    ];
  });

  /// The playlist and its entries in order, or null when it does not exist.
  /// Reads `tracks`: entries whose file is not in the library come back with
  /// a null track.
  Future<PlaylistPage?> playlistPage(int id) => transaction(() async {
    final playlist = await playlistSummary(id);
    if (playlist == null) return null;
    final rows = await customSelect(
      '''
SELECT e.id AS entry_id, e.path, t.id AS track_id, t.title, t.artist,
  t.album, t.year, t.duration_ms, t.cover_key
FROM playlist_entries e
LEFT JOIN tracks t ON t.path = e.path
WHERE e.playlist_id = ?1
ORDER BY e.position, e.id''',
      variables: [Variable.withInt(id)],
      readsFrom: {playlistEntries, tracks},
    ).get();
    return PlaylistPage(
      playlist: playlist,
      entries: [for (final row in rows) playlistEntryFromRow(row)],
    );
  });
}

PlaylistSummary _summary(QueryRow row) => PlaylistSummary(
  id: row.read<int>('id'),
  name: row.read<String>('name'),
  createdAt: row.read<int>('created_at'),
  entryCount: row.read<int>('n'),
  isFavorites: row.readNullable<String>('kind') == favoritesKind,
);
