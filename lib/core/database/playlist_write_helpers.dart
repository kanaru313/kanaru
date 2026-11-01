import 'package:drift/drift.dart';

import 'library_database.dart';
import 'playlist_favorites.dart';

/// Building blocks shared by the playlist write files. Callers own the
/// transaction: none of these opens one.
extension PlaylistWriteHelpers on LibraryDatabase {
  /// Inserts [paths] as given (repeats kept) into playlist [id] at positions
  /// `start..start+n-1`.
  Future<void> appendPlaylistPaths(
    int id,
    List<String> paths, {
    required int start,
  }) async {
    if (paths.isEmpty) return;
    await batch((b) {
      b.insertAll(playlistEntries, [
        for (var i = 0; i < paths.length; i++)
          PlaylistEntriesCompanion.insert(
            playlistId: id,
            path: paths[i],
            position: start + i,
          ),
      ]);
    });
  }

  /// Rewrites the positions of playlist [id] to `0..n-1`, keeping the order.
  Future<void> renumberPlaylist(int id) => customUpdate(
    '''
UPDATE playlist_entries AS e SET position = r.rn
FROM (SELECT id, ROW_NUMBER() OVER (ORDER BY position, id) - 1 AS rn
      FROM playlist_entries WHERE playlist_id = ?1) AS r
WHERE e.id = r.id AND e.position != r.rn''',
    variables: [Variable.withInt(id)],
    updates: {playlistEntries},
    updateKind: UpdateKind.update,
  );

  /// Number of entries of playlist [id].
  Future<int> playlistEntryCount(int id) async {
    final count = playlistEntries.id.count();
    final row =
        await (selectOnly(playlistEntries)
              ..addColumns([count])
              ..where(playlistEntries.playlistId.equals(id)))
            .getSingle();
    return row.read(count) ?? 0;
  }
}

/// Playlist [id] unless it is Favorites. `isNotValue` is SQL `IS NOT`, true
/// for the NULL kind of an ordinary playlist.
Expression<bool> userNamedPlaylist($PlaylistsTable p, int id) =>
    p.id.equals(id) & p.kind.isNotValue(favoritesKind);

/// [name] trimmed; a blank name throws [ArgumentError].
String validPlaylistName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(name, 'name', 'must not be blank');
  }
  return trimmed;
}
