import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_browse_queries.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../../../core/settings/settings_provider.dart';
import '../library_browse_refresh.dart';
import 'artist_sort.dart';
import 'artist_summaries.dart';

/// Every artist named in a track's `artist` tag, reloaded at most every
/// [libraryBrowseRefreshIntervalProvider] while the library changes. Empty
/// when the library is unavailable.
final artistsProvider = StreamProvider<List<ArtistSummary>>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return Stream.value(const []);
  return throttledTracksQuery(
    db,
    db.artistCredits,
    interval: ref.watch(libraryBrowseRefreshIntervalProvider),
  ).map(buildArtistSummaries);
});

/// [artistsProvider] in the saved sort, re-sorted in memory.
final sortedArtistsProvider = Provider<AsyncValue<List<ArtistSummary>>>((ref) {
  final sort = ref.watch(settingsProvider.select((s) => s.artistSort));
  return ref
      .watch(artistsProvider)
      .whenData((artists) => sortArtists(artists, sort));
});
