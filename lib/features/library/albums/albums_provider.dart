import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_browse_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../../../core/settings/settings_provider.dart';
import '../library_browse_refresh.dart';
import 'album_sort.dart';

/// Every album, reloaded at most every
/// [libraryBrowseRefreshIntervalProvider] while the library changes. Empty
/// when the library is unavailable.
final albumsProvider = StreamProvider<List<AlbumSummary>>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return Stream.value(const []);
  return throttledTracksQuery(
    db,
    db.albums,
    interval: ref.watch(libraryBrowseRefreshIntervalProvider),
  );
});

/// [albumsProvider] in the saved sort. Changing the sort re-sorts in memory
/// without querying again.
final sortedAlbumsProvider = Provider<AsyncValue<List<AlbumSummary>>>((ref) {
  final sort = ref.watch(settingsProvider.select((s) => s.albumSort));
  return ref
      .watch(albumsProvider)
      .whenData((albums) => sortAlbums(albums, sort));
});
