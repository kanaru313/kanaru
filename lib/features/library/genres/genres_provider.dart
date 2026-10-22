import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/genre_queries.dart';
import '../../../core/database/library_keys_provider.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../../../shared/genre_summaries.dart';
import '../../../shared/library_browse_refresh.dart';

/// Every genre named in the tracks, sorted by key, reloaded at most every
/// [libraryBrowseRefreshIntervalProvider] while the library changes. Empty
/// when the library is unavailable.
final genresProvider = StreamProvider<List<GenreSummary>>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return Stream.value(const []);
  // Wait for the keys: becoming ready rebuilds this and loads afresh.
  if (!ref.watch(keysReadyProvider)) return const Stream.empty();
  return throttledTracksQuery(
    db,
    db.genreCounts,
    interval: ref.watch(libraryBrowseRefreshIntervalProvider),
  ).map(buildGenreSummaries);
});
