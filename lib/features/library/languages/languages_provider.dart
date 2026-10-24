import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/language_queries.dart';
import '../../../core/database/library_keys_provider.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../../../shared/language_summaries.dart';
import '../../../shared/library_browse_refresh.dart';

/// Every language named by a language tag, sorted by key, reloaded at most
/// every [libraryBrowseRefreshIntervalProvider] while the library changes.
/// Empty when the library is unavailable.
final languagesProvider = StreamProvider<List<LanguageSummary>>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return Stream.value(const []);
  // Wait for the keys: becoming ready rebuilds this and loads afresh.
  if (!ref.watch(keysReadyProvider)) return const Stream.empty();
  return throttledTracksQuery(
    db,
    db.languageCounts,
    interval: ref.watch(libraryBrowseRefreshIntervalProvider),
  ).map(buildLanguageSummaries);
});
