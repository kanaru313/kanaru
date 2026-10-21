import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_browse_queries.dart';
import '../../../core/database/library_database.dart' show LibraryDatabase;
import '../../../core/database/library_keys_provider.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../../../shared/library_browse_refresh.dart';
import 'artist_page_sections.dart';

/// Reads the page of one artist (by key): tracks and album rows in one
/// transaction, arranged into sections. Null when no track credits the artist.
Future<ArtistPageSections?> readArtistSections(
  LibraryDatabase db,
  String artistKey,
) => db.transaction(() async {
  final (tracks, albums) = await (
    db.artistTracks(artistKey),
    db.artistAlbums(artistKey),
  ).wait;
  return tracks.isEmpty
      ? null
      : ArtistPageSections.fromTracks(artistKey, tracks, albums);
});

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
