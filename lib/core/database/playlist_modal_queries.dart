import 'package:drift/drift.dart';

import 'library_database.dart';

/// What the playlist modal counts beyond the page head.
class PlaylistModalStats {
  const PlaylistModalStats({required this.missing, required this.repeats});

  /// Entries whose file is not in the library.
  final int missing;

  /// Entries that repeat an earlier path of the same playlist.
  final int repeats;

  @override
  bool operator ==(Object other) =>
      other is PlaylistModalStats &&
      other.missing == missing &&
      other.repeats == repeats;

  @override
  int get hashCode => Object.hash(missing, repeats);
}

/// One-shot reads for the playlist modal.
extension PlaylistModalQueries on LibraryDatabase {
  /// Missing and repeated entry counts of playlist [id] (zeros when empty or
  /// gone). One aggregate, not a transaction; read when the modal opens.
  Future<PlaylistModalStats> playlistModalStats(int id) async {
    final row = await customSelect(
      '''
SELECT COALESCE(SUM(t.id IS NULL), 0) AS missing,
       COUNT(*) - COUNT(DISTINCT e.path) AS repeats
FROM playlist_entries e LEFT JOIN tracks t ON t.path = e.path
WHERE e.playlist_id = ?1''',
      variables: [Variable.withInt(id)],
      readsFrom: {playlistEntries, tracks},
    ).getSingle();
    return PlaylistModalStats(
      missing: row.read<int>('missing'),
      repeats: row.read<int>('repeats'),
    );
  }

  /// Ids of the entries of playlist [id] whose file has no `tracks` row, in
  /// order. Read at tap time and handed to `removePlaylistEntries`, so a scan
  /// in between never widens the delete.
  Future<List<int>> playlistMissingEntryIds(int id) => customSelect(
    '''
SELECT e.id FROM playlist_entries e
WHERE e.playlist_id = ?1
  AND NOT EXISTS (SELECT 1 FROM tracks t WHERE t.path = e.path)
ORDER BY e.position, e.id''',
    variables: [Variable.withInt(id)],
    readsFrom: {playlistEntries, tracks},
  ).map((row) => row.read<int>('id')).get();

  /// Every entry path of playlist [id] in order, repeats and missing files
  /// included.
  Future<List<String>> playlistEntryPaths(int id) => customSelect(
    '''
SELECT path FROM playlist_entries
WHERE playlist_id = ?1 ORDER BY position, id''',
    variables: [Variable.withInt(id)],
    readsFrom: {playlistEntries},
  ).map((row) => row.read<String>('path')).get();
}
