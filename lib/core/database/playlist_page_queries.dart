import 'package:drift/drift.dart';

import 'library_database.dart';
import 'playlist_page_shared.dart';
import 'playlist_queries.dart';
import 'playlist_rows.dart';

export 'playlist_page_shared.dart';

/// Reads for the windowed playlist page: the header on its own, a range of
/// entries by position, and the playable tracks for a queue. None of them
/// reads the whole playlist except [playlistPlayableTracks], which runs when
/// the user starts playback.
///
/// They rely on positions being dense (`0..n-1`), which every writer in
/// `playlist_writes.dart` keeps inside its transaction: the entry at index
/// `i` of the list is the one at `position = i`.
extension PlaylistPageQueries on LibraryDatabase {
  /// The header data of playlist [id], or null when it does not exist. One
  /// transaction; reads no entry rows. Reads `tracks` (collage, playable).
  Future<PlaylistPageHead?> playlistPageHead(int id) => transaction(() async {
    final playlist = await playlistSummary(id);
    if (playlist == null) return null;
    final coverKeys = await playlistCollageKeys(id);
    final playable = await customSelect(
      'SELECT EXISTS(SELECT 1 FROM playlist_entries e '
      'JOIN tracks t ON t.path = e.path WHERE e.playlist_id = ?1) AS any_row',
      variables: [Variable.withInt(id)],
      readsFrom: {playlistEntries, tracks},
    ).map((row) => row.read<int>('any_row') != 0).getSingle();
    return PlaylistPageHead(
      playlist: playlist,
      coverKeys: coverKeys,
      hasPlayable: playable,
    );
  });

  /// The entries of playlist [id] stored at positions `start` up to (not
  /// including) `start + count`, in order, each with its position. An entry
  /// whose file is not in the library comes back with a null track. A start
  /// past the end, or a count of zero, gives an empty list; the last page may
  /// be short.
  Future<List<PlaylistPositionedEntry>> playlistEntriesAt(
    int id,
    int start,
    int count,
  ) async {
    if (count <= 0) return const [];
    final rows = await customSelect(
      '''
SELECT e.id AS entry_id, e.position, e.path, t.id AS track_id, t.title,
  t.artist, t.album, t.year, t.duration_ms, t.cover_key
FROM playlist_entries e
LEFT JOIN tracks t ON t.path = e.path
WHERE e.playlist_id = ?1 AND e.position >= ?2 AND e.position < ?3
ORDER BY e.position, e.id''',
      variables: [
        Variable.withInt(id),
        Variable.withInt(start),
        Variable.withInt(start + count),
      ],
      readsFrom: {playlistEntries, tracks},
    ).get();
    return [
      for (final row in rows)
        PlaylistPositionedEntry(
          row.read<int>('position'),
          playlistEntryFromRow(row),
        ),
    ];
  }

  /// Every entry of playlist [id] whose file is in the library, in order.
  /// Reads the whole playlist: for a play queue, when the user asks for one.
  Future<List<PlaylistPlayableTrack>> playlistPlayableTracks(int id) async {
    final rows = await customSelect(
      '''
SELECT e.id AS entry_id, e.position, e.path, t.id AS track_id, t.title,
  t.artist, t.album, t.year, t.duration_ms, t.cover_key
FROM playlist_entries e
JOIN tracks t ON t.path = e.path
WHERE e.playlist_id = ?1
ORDER BY e.position, e.id''',
      variables: [Variable.withInt(id)],
      readsFrom: {playlistEntries, tracks},
    ).get();
    return [
      for (final row in rows)
        PlaylistPlayableTrack(
          entryId: row.read<int>('entry_id'),
          position: row.read<int>('position'),
          track: playlistEntryFromRow(row).track!,
        ),
    ];
  }
}
