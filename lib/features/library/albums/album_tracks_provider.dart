import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_browse_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';

/// The tracks of one album, live, by disc then track. Disposed when its page
/// closes.
final albumTracksProvider = StreamProvider.autoDispose
    .family<List<BrowseTrack>, AlbumKey>((ref, key) {
      final db = ref.watch(libraryDatabaseProvider);
      return db == null ? Stream.value(const []) : db.watchAlbumTracks(key);
    });
