import '../database/library_database.dart' hide Track;
import '../database/play_history_writes.dart';
import 'listen_playthrough.dart';
import 'play_write_chain.dart';

/// Queues the `plays` writes of a [ListenPlaythrough] on a [PlayWriteChain]:
/// one insert when it becomes a listen, then updates of its `listened_ms`.
class PlayRowWriter {
  PlayRowWriter(this._db, this._chain, this._now);

  final LibraryDatabase _db;
  final PlayWriteChain _chain;
  final DateTime Function() _now;

  /// Queues the row of [p]; it counts as a row (`pending`) from now on.
  void insert(ListenPlaythrough p) {
    p.row = PlayRow.pending;
    p.queued = p.acc.listened;
    final path = p.path!;
    final playedAt = p.playedAt ?? _now().millisecondsSinceEpoch;
    final listenedMs = p.queued.inMilliseconds;
    _chain.enqueue(() async {
      try {
        final id = await _db.insertLibraryPlay(
          path: path,
          playedAt: playedAt,
          listenedMs: listenedMs,
        );
        p.rowId = id;
        p.row = id == null ? PlayRow.dead : PlayRow.stored;
      } on Object {
        p.row = PlayRow.dead;
        rethrow;
      }
    });
  }

  /// Queues the current listening time of [p] into its row.
  void update(ListenPlaythrough p) {
    p.queued = p.acc.listened;
    final listenedMs = p.queued.inMilliseconds;
    _chain.enqueue(() async {
      // The id exists once the insert ahead in the chain has run.
      final id = p.rowId;
      if (p.row != PlayRow.stored || id == null) return;
      await _db.setPlayListened(id, listenedMs);
    });
  }
}
