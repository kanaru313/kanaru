import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_browse_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_keys_provider.dart';
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
  // Wait for the keys: becoming ready rebuilds this and loads afresh.
  if (!ref.watch(keysReadyProvider)) return const Stream.empty();
  return throttledTracksQuery(
    db,
    db.albums,
    interval: ref.watch(libraryBrowseRefreshIntervalProvider),
  );
});

/// [albumsProvider] in the saved sort. Changing the sort re-sorts in memory
/// without querying again. Null until the first list loaded.
final sortedAlbumsProvider = Provider<List<AlbumSummary>?>((ref) {
  final sort = ref.watch(settingsProvider.select((s) => s.albumSort));
  // `value` keeps the last list through a failed or running reload.
  final list = ref.watch(albumsProvider).value;
  return list == null ? null : sortAlbums(list, sort);
});
