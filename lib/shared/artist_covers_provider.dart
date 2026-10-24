import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/artist_cover_queries.dart';
import '../core/database/library_keys_provider.dart';
import '../core/database/library_startup.dart';
import '../core/database/throttled_tracks_query.dart';
import 'library_browse_refresh.dart';

/// Cover key by artist key: the cover of the artist's first album with one
/// (see `artistCoversSql`), reloaded at most every
/// [libraryBrowseRefreshIntervalProvider] while the library changes. Empty
/// when the library is unavailable.
final artistCoversProvider = StreamProvider<Map<String, String>>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return Stream.value(const {});
  // Wait for the keys: becoming ready rebuilds this and loads afresh.
  if (!ref.watch(keysReadyProvider)) return const Stream.empty();
  return throttledTracksQuery(
    db,
    db.artistCovers,
    interval: ref.watch(libraryBrowseRefreshIntervalProvider),
  );
});
