import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_browse_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_keys_provider.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../library_browse_refresh.dart';

/// The title, artist, year, duration and cover of one album, from the same
/// query rows as the albums list, so the page shows what the list shows.
/// Null when the album has no tracks. Reloaded like [albumTracksProvider];
/// disposed when its page closes.
final albumSummaryProvider = StreamProvider.autoDispose
    .family<AlbumSummary?, AlbumKey>((ref, key) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(null);
      // Wait for the keys: becoming ready rebuilds this and loads afresh.
      if (!ref.watch(keysReadyProvider)) return const Stream.empty();
      return throttledTracksQuery(
        db,
        () => db.album(key),
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      );
    });
