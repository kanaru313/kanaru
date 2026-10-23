import 'package:drift/drift.dart';

import 'library_database.dart';
import 'playlist_cover_keys.dart';
import 'queue_history_kind.dart';

/// One saved queue as the queue history page lists it.
class QueueSnapshotCard {
  const QueueSnapshotCard({
    required this.id,
    required this.savedAt,
    required this.trackCount,
    required this.coverKeys,
  });

  /// The `playlists` row id.
  final int id;

  /// When the queue was replaced (or last replaced again unchanged), epoch
  /// milliseconds: the `created_at` of the row.
  final int savedAt;

  /// Entries, repeats included.
  final int trackCount;

  /// Collage keys (see `pickCollageKeys`).
  final List<String> coverKeys;
}

/// Reads of the queue history: the queues the user replaced, kept as
/// playlists of kind `'queue'` (invariant 8 of `user_data_tables.dart`).
/// Writes are in `queue_history_writes.dart`.
extension QueueHistoryQueries on LibraryDatabase {
  /// Every saved queue, newest first, with its collage. Reads `tracks` for
  /// the covers, so callers wrap it in `throttledTracksQuery`.
  Future<List<QueueSnapshotCard>> queueSnapshots() => transaction(() async {
    final rows = await customSelect(
      '''
SELECT p.id, p.created_at,
  (SELECT COUNT(*) FROM playlist_entries e WHERE e.playlist_id = p.id) AS n
FROM playlists p
WHERE p.kind = ?1
ORDER BY p.created_at DESC, p.id DESC''',
      variables: [Variable.withString(queueSnapshotKind)],
      readsFrom: {playlists, playlistEntries},
    ).get();
    return [
      for (final row in rows)
        QueueSnapshotCard(
          id: row.read<int>('id'),
          savedAt: row.read<int>('created_at'),
          trackCount: row.read<int>('n'),
          coverKeys: await _snapshotCollage(row.read<int>('id')),
        ),
    ];
  });

  /// When saved queue [id] was saved (epoch milliseconds), or null when no
  /// saved queue has that id (gone, or an ordinary playlist).
  Future<int?> queueSnapshotSavedAt(int id) => customSelect(
    'SELECT created_at FROM playlists WHERE id = ?1 AND kind = ?2',
    variables: [Variable.withInt(id), Variable.withString(queueSnapshotKind)],
    readsFrom: {playlists},
  ).map((row) => row.read<int>('created_at')).getSingleOrNull();

  /// The paths of saved queue [id] in play order; empty when it is gone or
  /// is not a saved queue.
  Future<List<String>> queueSnapshotPaths(int id) => customSelect(
    '''
SELECT e.path FROM playlist_entries e
JOIN playlists p ON p.id = e.playlist_id
WHERE e.playlist_id = ?1 AND p.kind = ?2
ORDER BY e.position, e.id''',
    variables: [Variable.withInt(id), Variable.withString(queueSnapshotKind)],
    readsFrom: {playlists, playlistEntries},
  ).map((row) => row.read<String>('path')).get();

  /// Deletes saved queue [id] with its entries. Never deletes an ordinary
  /// playlist or Favorites.
  Future<void> deleteQueueSnapshot(int id) => (delete(
    playlists,
  )..where((p) => p.id.equals(id) & p.kind.equals(queueSnapshotKind))).go();

  Future<List<String>> _snapshotCollage(int id) async {
    final rows = await customSelect(
      '''
SELECT t.cover_key FROM playlist_entries e
JOIN tracks t ON t.path = e.path
WHERE e.playlist_id = ?1 AND t.cover_key IS NOT NULL
ORDER BY e.position, e.id
LIMIT $playlistCollageScanLimit''',
      variables: [Variable.withInt(id)],
    ).get();
    return pickCollageKeys(rows.map((r) => r.read<String>('cover_key')));
  }
}
