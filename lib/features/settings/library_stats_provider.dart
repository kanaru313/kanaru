import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_keys_provider.dart';
import '../../core/database/library_startup.dart';
import '../../core/database/library_stats_queries.dart';
import '../../core/database/throttled_tracks_query.dart';
import '../../shared/library_browse_refresh.dart';

/// The library's counts, reloaded at most every
/// [libraryBrowseRefreshIntervalProvider] while the library changes, and
/// only while Settings is open. Null without a library; no value while the
/// keys the counts group by are still being made.
final libraryStatsProvider = StreamProvider.autoDispose<LibraryStats?>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return Stream.value(null);
  if (!ref.watch(keysReadyProvider)) return const Stream.empty();
  return throttledTracksQuery<LibraryStats?>(
    db,
    db.libraryStats,
    interval: ref.watch(libraryBrowseRefreshIntervalProvider),
  );
});
