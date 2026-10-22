import 'package:drift/drift.dart';

import 'library_database.dart';

/// Writes to `plays`, the only play-history table the app writes: the
/// triggers in `listen_history.drift` keep `play_stats` in step. Everything
/// goes through drift's API so table watchers re-run.
extension PlayHistoryWrites on LibraryDatabase {
  /// Inserts a play of the library track at [path], started at [playedAt]
  /// (epoch ms) with [listenedMs] listened so far, and returns its id. Returns
  /// `null`, writing nothing, when no track row has exactly this path. The
  /// lookup and the insert share one transaction, so a rescan cannot remove
  /// the track in between.
  Future<int?> insertLibraryPlay({
    required String path,
    required int playedAt,
    required int listenedMs,
  }) => transaction(() async {
    final known =
        await (selectOnly(tracks)
              ..addColumns([tracks.id])
              ..where(tracks.path.equals(path))
              ..limit(1))
            .getSingleOrNull();
    if (known == null) return null;
    return into(plays).insert(
      PlaysCompanion.insert(
        path: path,
        playedAt: playedAt,
        listenedMs: Value(listenedMs),
      ),
    );
  });

  /// Sets `listened_ms` of play [id] and nothing else. `false` when the row
  /// is gone, for example because the history was cleared; it is never
  /// recreated.
  Future<bool> setPlayListened(int id, int listenedMs) async {
    final changed = await (update(plays)..where((p) => p.id.equals(id))).write(
      PlaysCompanion(listenedMs: Value(listenedMs)),
    );
    return changed > 0;
  }

  /// Deletes every play; the triggers empty `play_stats`. Returns how many
  /// plays were removed.
  Future<int> clearPlayHistory() => delete(plays).go();
}
