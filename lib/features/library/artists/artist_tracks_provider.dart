import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_browse_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';

/// The tracks crediting one artist (by key), live. Disposed when its page
/// closes.
final artistTracksProvider = StreamProvider.autoDispose
    .family<List<BrowseTrack>, String>((ref, artistKey) {
      final db = ref.watch(libraryDatabaseProvider);
      return db == null
          ? Stream.value(const [])
          : db.watchArtistTracks(artistKey);
    });
