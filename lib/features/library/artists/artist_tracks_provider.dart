import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_browse_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_keys_provider.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../library_browse_refresh.dart';

/// The tracks crediting one artist (by key), reloaded at most every
/// [libraryBrowseRefreshIntervalProvider] while the library changes.
/// Disposed when its page closes.
final artistTracksProvider = StreamProvider.autoDispose
    .family<List<BrowseTrack>, String>((ref, artistKey) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(const []);
      // Wait for the keys: becoming ready rebuilds this and loads afresh.
      if (!ref.watch(keysReadyProvider)) return const Stream.empty();
      return throttledTracksQuery(
        db,
        () => db.artistTracks(artistKey),
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      );
    });
