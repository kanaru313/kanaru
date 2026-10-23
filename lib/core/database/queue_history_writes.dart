import 'dart:convert';

import 'package:drift/drift.dart';

import 'library_database.dart';
import 'queue_history_kind.dart';

/// What [QueueHistoryWrites.recordQueueSnapshot] did.
enum QueueSnapshotOutcome {
  /// Too few tracks: nothing written.
  tooShort,

  /// Same paths in the same order as the newest saved queue: only its time
  /// moved to now.
  touched,

  /// A new saved queue.
  saved,
}

/// Writes of the queue history (reads: `queue_history_queries.dart`).
extension QueueHistoryWrites on LibraryDatabase {
  /// Saves a replaced queue: [paths] in play order, canonical (invariant 1),
  /// at epoch milliseconds [now]. All in one transaction: a queue equal to
  /// the newest saved one only moves that one's time; otherwise a new row
  /// with dense positions goes in and the saved queues beyond
  /// [queueSnapshotLimit] are deleted, oldest first, with their entries.
  ///
  /// The paths travel as one JSON array and are compared and inserted inside
  /// SQLite, so a queue of a whole library never comes back to Dart.
  Future<QueueSnapshotOutcome> recordQueueSnapshot(
    List<String> paths, {
    required int now,
  }) {
    if (paths.length < queueSnapshotMinTracks) {
      return Future.value(QueueSnapshotOutcome.tooShort);
    }
    final json = jsonEncode(paths);
    return transaction(() async {
      final newest = await customSelect(
        'SELECT id FROM playlists WHERE kind = ?1 '
        'ORDER BY created_at DESC, id DESC LIMIT 1',
        variables: [Variable.withString(queueSnapshotKind)],
        readsFrom: {playlists},
      ).map((row) => row.read<int>('id')).getSingleOrNull();
      if (newest != null && await _samePaths(newest, json, paths.length)) {
        await (update(playlists)..where((p) => p.id.equals(newest))).write(
          PlaylistsCompanion(createdAt: Value(now)),
        );
        return QueueSnapshotOutcome.touched;
      }
      final id = await into(playlists).insert(
        PlaylistsCompanion.insert(
          name: queueSnapshotStoredName,
          createdAt: now,
          kind: const Value(queueSnapshotKind),
        ),
      );
      await customInsert(
        'INSERT INTO playlist_entries (playlist_id, path, position) '
        'SELECT ?1, value, key FROM json_each(?2)',
        variables: [Variable.withInt(id), Variable.withString(json)],
        updates: {playlistEntries},
      );
      await customUpdate(
        '''
DELETE FROM playlists WHERE kind = ?1 AND id NOT IN (
  SELECT id FROM playlists WHERE kind = ?1
  ORDER BY created_at DESC, id DESC LIMIT ?2)''',
        variables: [
          Variable.withString(queueSnapshotKind),
          Variable.withInt(queueSnapshotLimit),
        ],
        updates: {playlists, playlistEntries},
        updateKind: UpdateKind.delete,
      );
      return QueueSnapshotOutcome.saved;
    });
  }

  /// Whether saved queue [id] holds exactly the [count] paths of the JSON
  /// array [json], in that order.
  Future<bool> _samePaths(int id, String json, int count) async {
    final row = await customSelect(
      '''
SELECT
  (SELECT COUNT(*) FROM playlist_entries WHERE playlist_id = ?1) AS n,
  (SELECT COUNT(*) FROM json_each(?2) j
   JOIN (SELECT path, ROW_NUMBER() OVER (ORDER BY position, id) - 1 AS i
         FROM playlist_entries WHERE playlist_id = ?1) e
   ON e.i = j.key AND e.path = j.value) AS same''',
      variables: [Variable.withInt(id), Variable.withString(json)],
      readsFrom: {playlistEntries},
    ).getSingle();
    return row.read<int>('n') == count && row.read<int>('same') == count;
  }
}
