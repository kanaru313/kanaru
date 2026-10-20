import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/library_keys_provider.dart';
import '../../../core/database/library_song_paging.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../../../core/settings/settings_provider.dart';
import '../library_browse_refresh.dart';

/// The track ids of the Songs list in one sort, with the sort they were read
/// in so a tap can read the matching queue.
class SongIds {
  const SongIds(this.ids, this.order, this.descending);

  final List<int> ids;
  final SongOrder order;
  final bool descending;
}

/// Every stored track id in the saved Songs sort, reloaded at most every
/// [libraryBrowseRefreshIntervalProvider] while the library changes. Empty
/// when the library is unavailable. The rows are read page by page for the
/// ids on screen (`SongRowCache`). The shell keeps the Songs branch mounted,
/// so the provider stays alive when another tab is shown but is paused there
/// (Riverpod pauses listeners under `TickerMode` false): a scan elsewhere
/// does not reload it, and it reloads once on return if the library changed.
/// It is disposed when the list leaves the widget tree.
final songIdsProvider = StreamProvider.autoDispose<SongIds>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  final sort = ref.watch(settingsProvider.select((s) => s.songSort));
  final order = songOrderFor(sort.field);
  if (db == null) return Stream.value(SongIds(const [], order, false));
  // Wait for the keys: becoming ready rebuilds this and loads afresh.
  if (!ref.watch(keysReadyProvider)) return const Stream.empty();
  return throttledTracksQuery(
    db,
    () async => SongIds(
      await db.songIds(order: order, descending: sort.descending),
      order,
      sort.descending,
    ),
    interval: ref.watch(libraryBrowseRefreshIntervalProvider),
  );
});

/// The first page in the saved sort, read at once so rows show while
/// [songIdsProvider] is still reading the ids of a large library.
final songsFirstPageProvider = FutureProvider.autoDispose<List<TrackListItem>>((
  ref,
) async {
  final db = ref.watch(libraryDatabaseProvider);
  final sort = ref.watch(settingsProvider.select((s) => s.songSort));
  if (db == null || !ref.watch(keysReadyProvider)) return const [];
  return db.songsPage(
    order: songOrderFor(sort.field),
    descending: sort.descending,
  );
});

/// The database order for a Songs sort field (the database does not know
/// the settings).
SongOrder songOrderFor(SongSortField field) => switch (field) {
  SongSortField.title => SongOrder.title,
  SongSortField.artist => SongOrder.artist,
  SongSortField.album => SongOrder.album,
  SongSortField.year => SongOrder.year,
  SongSortField.dateAdded => SongOrder.dateAdded,
  SongSortField.duration => SongOrder.duration,
};
