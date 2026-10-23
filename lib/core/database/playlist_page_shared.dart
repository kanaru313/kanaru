import 'package:drift/drift.dart';

import 'library_database.dart';
import 'playlist_cover_keys.dart';
import 'playlist_rows.dart';

/// Row mapping and the collage read shared by the playlist grid
/// (`playlist_queries.dart`) and the playlist page
/// (`playlist_page_queries.dart`), so the two never disagree.
extension PlaylistCollageQueries on LibraryDatabase {
  /// Cover keys of the first covered entries by position, reduced to the
  /// collage. Only the first [playlistCollageEntryScanLimit] entries are
  /// looked at (before joining `tracks`), and at most
  /// [playlistCollageScanLimit] covered ones.
  Future<List<String>> playlistCollageKeys(int playlistId) async {
    final rows = await customSelect(
      '''
SELECT t.cover_key FROM (
  SELECT path, position, id FROM playlist_entries
  WHERE playlist_id = ?1 ORDER BY position, id
  LIMIT $playlistCollageEntryScanLimit) e
JOIN tracks t ON t.path = e.path
WHERE t.cover_key IS NOT NULL
ORDER BY e.position, e.id
LIMIT $playlistCollageScanLimit''',
      variables: [Variable.withInt(playlistId)],
      readsFrom: {playlistEntries, tracks},
    ).get();
    return pickCollageKeys(rows.map((r) => r.read<String>('cover_key')));
  }
}

/// The entry in [row], which holds `entry_id`, `path` and the left-joined
/// track columns (`track_id`, `title`, `artist`, `album`, `duration_ms`,
/// `cover_key`); the track is null when `track_id` is.
PlaylistEntryRow playlistEntryFromRow(QueryRow row) {
  final trackId = row.readNullable<int>('track_id');
  final path = row.read<String>('path');
  return PlaylistEntryRow(
    entryId: row.read<int>('entry_id'),
    path: path,
    track: trackId == null
        ? null
        : TrackListItem(
            id: trackId,
            path: path,
            title: row.read<String>('title'),
            artist: row.readNullable<String>('artist'),
            album: row.readNullable<String>('album'),
            durationMs: row.readNullable<int>('duration_ms'),
            coverKey: row.readNullable<String>('cover_key'),
          ),
  );
}
