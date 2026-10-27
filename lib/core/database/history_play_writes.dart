import 'dart:math' as math;

import 'package:drift/drift.dart';

import 'library_database.dart';

/// Delete and restore of plays (single or in lists), for the history page's Undo. Both go
/// through drift's API so the `play_stats` triggers and table watchers run;
/// `play_stats` is never written here.
extension HistoryPlayWrites on LibraryDatabase {
  /// Deletes play [id] and returns the row as it was, or null when it is
  /// already gone. The `plays_stats_delete` trigger updates `play_stats`.
  Future<Play?> deletePlay(int id) => transaction(() async {
    final old = await (select(
      plays,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    if (old == null) return null;
    await (delete(plays)..where((p) => p.id.equals(id))).go();
    return old;
  });

  /// Puts back a row returned by [deletePlay], with the same `id`, `path`,
  /// `played_at` and `listened_ms`. Returns false, writing nothing, when a
  /// row with that id exists (a second Undo tap). Not a door for inserting
  /// arbitrary plays: pass only what [deletePlay] returned.
  ///
  /// The same id is free: `plays.id` is AUTOINCREMENT, so it is never handed
  /// out again. The recorder keeps the `rowId` of the play it is recording, so
  /// a checkpoint after the Undo writes again when that play is still
  /// playing. A checkpoint that landed while the row was absent was dropped
  /// while the recorder counted it as written, so `listened_ms` may be lower
  /// than the real time. The track need not be in `tracks` (rows survive a
  /// rescan) and `path` keeps its original spelling. Plain `INSERT`, not
  /// `OR REPLACE`/`OR IGNORE`: the insert trigger is an UPSERT already.
  Future<bool> restorePlay(Play play) => transaction(() async {
    final exists =
        await (selectOnly(plays)
              ..addColumns([plays.id])
              ..where(plays.id.equals(play.id)))
            .getSingleOrNull();
    if (exists != null) return false;
    await into(plays).insert(
      PlaysCompanion.insert(
        id: Value(play.id),
        path: play.path,
        playedAt: play.playedAt,
        listenedMs: Value(play.listenedMs),
      ),
    );
    return true;
  });

  /// Deletes the plays with these [ids] in one transaction and returns the
  /// rows that existed, newest first (`played_at DESC, id DESC`). Ids already
  /// gone are skipped. The caller passes the ids it showed, so a play recorded
  /// meanwhile is never taken.
  Future<List<Play>> deletePlaysByIds(List<int> ids) => transaction(() async {
    final old = <Play>[];
    // SQLite caps the number of variables of one statement.
    for (var i = 0; i < ids.length; i += _idChunk) {
      final chunk = ids.sublist(i, math.min(i + _idChunk, ids.length));
      old.addAll(await (select(plays)..where((p) => p.id.isIn(chunk))).get());
      await (delete(plays)..where((p) => p.id.isIn(chunk))).go();
    }
    old.sort((a, b) {
      final byTime = b.playedAt.compareTo(a.playedAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
    return old;
  });

  /// Puts back rows returned by [deletePlaysByIds], one transaction, with the
  /// rule of [restorePlay] for each: an id that exists is skipped. Returns the
  /// rows written.
  Future<int> restorePlays(List<Play> toRestore) => transaction(() async {
    var written = 0;
    for (final play in toRestore) {
      if (await restorePlay(play)) written++;
    }
    return written;
  });
}

const _idChunk = 500;
