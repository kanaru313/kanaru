import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/queue_history_queries.dart';
import '../../core/database/throttled_tracks_query.dart';
import '../../shared/library_browse_refresh.dart';

/// The saved queues, newest first; empty without a library.
///
/// A write to the playlist tables (a queue saved, a saved queue deleted or
/// edited) starts a fresh stream whose first load is immediate; a scan only
/// marks the stream dirty, so it reloads at most every
/// `libraryBrowseRefreshIntervalProvider` (the covers come from `tracks`).
final queueSnapshotsProvider =
    StreamProvider.autoDispose<List<QueueSnapshotCard>>((ref) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(const []);
      final edits = db
          .tableUpdates(
            TableUpdateQuery.onAllTables([db.playlists, db.playlistEntries]),
          )
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(edits.cancel);
      return throttledTracksQuery(
        db,
        db.queueSnapshots,
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      );
    });

/// When saved queue [id] was saved, epoch milliseconds; null when no saved
/// queue has that id (gone, or an ordinary playlist) or without a library.
/// Read again on every write to `playlists`.
final queueSnapshotSavedAtProvider = FutureProvider.autoDispose
    .family<int?, int>((ref, id) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Future.value();
      final edits = db
          .tableUpdates(TableUpdateQuery.onTable(db.playlists))
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(edits.cancel);
      return db.queueSnapshotSavedAt(id);
    });
