import 'dart:convert';

import 'package:drift/drift.dart';

import 'library_database.dart';

extension PlaylistAddQueries on LibraryDatabase {
  /// For each ordinary playlist (no Favorites, no saved queue) holding at
  /// least one of [paths], how many distinct paths of the batch it holds.
  /// Playlists with no overlap are absent. [playlistIds] limits the playlists
  /// looked at. Paths go in as one JSON array: SQLite caps the variables of a
  /// statement and a folder can hold thousands of songs.
  Future<Map<int, int>> playlistOverlapCounts(
    List<String> paths, {
    Iterable<int>? playlistIds,
  }) async {
    if (paths.isEmpty || (playlistIds != null && playlistIds.isEmpty)) {
      return {};
    }
    final rows = await customSelect(
      'SELECT e.playlist_id AS id, COUNT(DISTINCT e.path) AS k '
      'FROM playlist_entries e JOIN playlists p ON p.id = e.playlist_id '
      'WHERE p.kind IS NULL '
      'AND e.path IN (SELECT value FROM json_each(?1)) '
      '${playlistIds == null ? '' : 'AND e.playlist_id IN (SELECT value FROM json_each(?2)) '}'
      'GROUP BY e.playlist_id',
      variables: [
        Variable.withString(jsonEncode(paths.toSet().toList())),
        if (playlistIds != null)
          Variable.withString(jsonEncode(playlistIds.toList())),
      ],
      readsFrom: {playlistEntries, playlists},
    ).get();
    return {for (final row in rows) row.read<int>('id'): row.read<int>('k')};
  }
}
