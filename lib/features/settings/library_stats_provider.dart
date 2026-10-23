import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/genre_queries.dart';
import '../../core/database/library_keys_provider.dart';
import '../../core/database/library_startup.dart';
import '../../core/database/library_stats_queries.dart';
import '../../core/database/separator_rules_provider.dart';
import '../../core/database/throttled_tracks_query.dart';
import '../../shared/genre_summaries.dart';
import '../../shared/library_browse_refresh.dart';
import '../../shared/library_route_keys.dart' show unknownGenreKey;

/// How much the library holds, as the Albums, Artists and Genres lists
/// would count it.
typedef LibraryStats = ({int tracks, int albums, int artists, int genres});

/// The library's counts, reloaded at most every
/// [libraryBrowseRefreshIntervalProvider] while the library changes, and
/// only while Settings is open. Null without a library; no value while the
/// keys the counts group by are still being made.
///
/// Genres are counted as the Genres list lists them (split by the current
/// separators, without the "unknown" entry), so the number matches it.
final libraryStatsProvider = StreamProvider.autoDispose<LibraryStats?>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return Stream.value(null);
  if (!ref.watch(keysReadyProvider)) return const Stream.empty();
  final genreRules = ref.watch(genreSplitRulesProvider);
  return throttledTracksQuery<LibraryStats?>(db, () async {
    final counts = await db.libraryStats();
    final genres = buildGenreSummaries(
      await db.genreCounts(),
      rules: genreRules,
    ).where((genre) => genre.key != unknownGenreKey).length;
    return (
      tracks: counts.tracks,
      albums: counts.albums,
      artists: counts.artists,
      genres: genres,
    );
  }, interval: ref.watch(libraryBrowseRefreshIntervalProvider));
});
