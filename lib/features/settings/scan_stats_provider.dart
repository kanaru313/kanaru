import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/scan_stats_queries.dart';
import '../../core/database/throttled_tracks_query.dart';
import '../../shared/library_browse_refresh.dart';

/// The scan numbers the database holds (tracks, tag errors, covers),
/// reloaded at most every [libraryBrowseRefreshIntervalProvider] while the
/// library changes, and only while Settings is open. Null without a library.
final scanDbStatsProvider = StreamProvider.autoDispose<ScanDbStats?>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return Stream.value(null);
  return throttledTracksQuery<ScanDbStats?>(
    db,
    db.scanDbStats,
    interval: ref.watch(libraryBrowseRefreshIntervalProvider),
  );
});
