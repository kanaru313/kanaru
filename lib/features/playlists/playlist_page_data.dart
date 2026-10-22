import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_database.dart';
import '../../core/database/library_startup.dart';
import '../../core/database/playlist_queries.dart';
import '../../core/database/playlist_rows.dart';
import '../../core/database/throttled_tracks_query.dart';
import '../../shared/library_browse_refresh.dart';

/// Runs [load] at once on playlist edits and at most every
/// `libraryBrowseRefreshIntervalProvider` while `tracks` changes.
///
/// An edit invalidates the provider, which starts a fresh stream whose first
/// load is immediate; a scan only marks the running stream dirty, so a scan
/// cannot keep the database busy with reloads (see `throttledTracksQuery`).
/// Every load builds new row objects: the page view tells new data from a
/// reload state by identity.
Stream<T> _playlistQuery<T>(
  Ref ref,
  LibraryDatabase db,
  Future<T> Function() load,
) {
  final edits = db
      .tableUpdates(
        TableUpdateQuery.onAllTables([db.playlists, db.playlistEntries]),
      )
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(edits.cancel);
  return throttledTracksQuery(
    db,
    load,
    interval: ref.watch(libraryBrowseRefreshIntervalProvider),
  );
}

/// One playlist with its entries; null when it does not exist (or without a
/// library).
final playlistPageProvider = StreamProvider.autoDispose
    .family<PlaylistPage?, int>((ref, id) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(null);
      return _playlistQuery(ref, db, () => db.playlistPage(id));
    });

/// Every playlist with its collage keys, newest first.
final playlistCardsProvider = StreamProvider.autoDispose<List<PlaylistCard>>((
  ref,
) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return Stream.value(const []);
  return _playlistQuery(ref, db, db.playlistCards);
});
