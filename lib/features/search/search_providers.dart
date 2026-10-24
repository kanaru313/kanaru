import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_browse_queries.dart';
import '../../core/database/library_browse_rows.dart';
import '../../core/database/library_database.dart' show TrackListItem;
import '../../core/database/library_keys_provider.dart';
import '../../core/database/library_startup.dart';
import '../../core/database/search_album_artist_names.dart';
import '../../core/database/search_name_index.dart';
import '../../core/database/throttled_tracks_query.dart';
import '../../shared/artist_summaries.dart';
import '../../shared/library_browse_refresh.dart';

/// Every album, ready to filter by search terms. Loaded like the Albums
/// list: after the keys are ready, reloaded (throttled) while the library
/// changes. Empty when the library is unavailable.
final searchAlbumIndexProvider =
    StreamProvider.autoDispose<SearchNameIndex<AlbumSummary>>((ref) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(albumSearchIndex(const []));
      // Becoming ready rebuilds this and loads afresh.
      if (!ref.watch(keysReadyProvider)) return const Stream.empty();
      return throttledTracksQuery(db, () async {
        final albums = await db.albums();
        // The extra read runs whenever any album merges several artists (in
        // practice always with album-artist grouping off). It is throttled
        // with the rest and only runs while search is listened to.
        final names = albums.any((a) => a.variousArtists)
            ? await db.mergedAlbumArtistNames()
            : const <AlbumKey, List<String>>{};
        return albumSearchIndex(albums, artistNames: names);
      }, interval: ref.watch(libraryBrowseRefreshIntervalProvider));
    });

/// Every artist credit, ready to filter by search terms; see
/// [searchAlbumIndexProvider].
final searchArtistIndexProvider =
    StreamProvider.autoDispose<SearchNameIndex<ArtistCredit>>((ref) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(artistSearchIndex(const []));
      if (!ref.watch(keysReadyProvider)) return const Stream.empty();
      return throttledTracksQuery(
        db,
        db.artistCredits,
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      ).map(artistSearchIndex);
    });

/// What a query found, in the three groups of the search page.
class SearchResults {
  const SearchResults({
    required this.songs,
    required this.songTotal,
    required this.albums,
    required this.artists,
    this.corrections = const {},
    this.needsVocabulary = false,
  });

  /// The best songs, at most `searchSongLimit`.
  final List<TrackListItem> songs;

  /// Every song that matched, which can be more than [songs].
  final int songTotal;
  final List<AlbumSummary> albums;
  final List<ArtistSummary> artists;

  /// Misspelt words of the query and what they were read as: not empty when
  /// part of these results come from the corrected query.
  final Map<String, String> corrections;

  /// Whether the real songs were few and a word of the query could be
  /// corrected: the typo dictionary is worth keeping loaded.
  final bool needsVocabulary;

  bool get isEmpty => songs.isEmpty && albums.isEmpty && artists.isEmpty;
}
