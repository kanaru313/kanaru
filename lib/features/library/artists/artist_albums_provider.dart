import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_browse_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_keys_provider.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../library_browse_refresh.dart';

/// The albums holding tracks of one artist (by key), with the same details
/// as the albums list, whole-album covers included. Reloaded like
/// [artistTracksProvider]'s tracks; disposed when the page closes.
final artistAlbumsProvider = StreamProvider.autoDispose
    .family<List<AlbumSummary>, String>((ref, artistKey) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(const []);
      // Wait for the keys: becoming ready rebuilds this and loads afresh.
      if (!ref.watch(keysReadyProvider)) return const Stream.empty();
      return throttledTracksQuery(
        db,
        () => db.artistAlbums(artistKey),
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      );
    });
