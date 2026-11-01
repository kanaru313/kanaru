import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_keys_provider.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../../../shared/library_browse_refresh.dart';
import '../../../shared/artist_page/artist_page_sections.dart';
import '../../../shared/artist_page/read_artist_sections.dart';

/// The whole page of one artist (by key): tracks and album rows read in one
/// transaction, arranged into sections right away (not in `build`), and
/// reloaded at most every [libraryBrowseRefreshIntervalProvider] while the
/// library changes. Null when no track credits the artist any more. Disposed
/// when its page closes.
final artistPageProvider = StreamProvider.autoDispose
    .family<ArtistPageSections?, String>((ref, artistKey) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(null);
      // Wait for the keys: becoming ready rebuilds this and loads afresh.
      if (!ref.watch(keysReadyProvider)) return const Stream.empty();
      return throttledTracksQuery(
        db,
        () => readArtistSections(db, artistKey),
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      );
    });
