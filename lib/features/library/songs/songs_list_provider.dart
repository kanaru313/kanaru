import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_browse_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../../../core/settings/settings_provider.dart';
import '../library_browse_refresh.dart';

/// Every stored track in the saved Songs sort, reloaded at most every
/// [libraryBrowseRefreshIntervalProvider] while the library changes. Empty
/// when the library is unavailable. The whole list is loaded: fine for a
/// minimal list, a windowed query comes with the full songs page. The shell
/// keeps the Songs branch mounted, so the provider stays alive when another
/// tab is shown but is paused there (Riverpod pauses listeners under
/// `TickerMode` false): a scan elsewhere does not reload it, and it reloads
/// once on return if the library changed. It is disposed when the list
/// leaves the widget tree.
final songsListProvider = StreamProvider.autoDispose<List<TrackListItem>>((
  ref,
) {
  final db = ref.watch(libraryDatabaseProvider);
  final sort = ref.watch(settingsProvider.select((s) => s.songSort));
  if (db == null) return Stream.value(const []);
  return throttledTracksQuery(
    db,
    () =>
        db.songs(order: songOrderFor(sort.field), descending: sort.descending),
    interval: ref.watch(libraryBrowseRefreshIntervalProvider),
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
