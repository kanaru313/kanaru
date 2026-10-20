import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_browse_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../library_browse_refresh.dart';

/// The tracks of one album by disc then track, reloaded at most every
/// [libraryBrowseRefreshIntervalProvider] while the library changes (the
/// query scans every distinct tag, so a plain watch would slow a scan).
/// Disposed when its page closes.
final albumTracksProvider = StreamProvider.autoDispose
    .family<List<BrowseTrack>, AlbumKey>((ref, key) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(const []);
      return throttledTracksQuery(
        db,
        () => db.albumTracks(key),
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      );
    });
