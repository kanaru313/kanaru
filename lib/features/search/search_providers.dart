import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_browse_queries.dart';
import '../../core/database/library_browse_rows.dart';
import '../../core/database/library_database.dart' show TrackListItem;
import '../../core/database/library_keys_provider.dart';
import '../../core/database/library_search_queries.dart';
import '../../core/database/library_startup.dart';
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
      return throttledTracksQuery(
        db,
        db.albums,
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      ).map(albumSearchIndex);
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

/// The best songs for a query, keyed by its terms joined with spaces (terms
/// never hold one). Reloaded (throttled) while the library changes.
final searchSongsProvider = StreamProvider.autoDispose
    .family<SongSearchResult, String>((ref, termsKey) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(SongSearchResult.empty);
      final terms = termsKey.split(' ');
      return throttledTracksQuery(
        db,
        () => db.searchSongs(terms),
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      );
    });

/// What a query found, in the three groups of the search page.
class SearchResults {
  const SearchResults({
    required this.songs,
    required this.songTotal,
    required this.albums,
    required this.artists,
  });

  /// The best songs, at most `searchSongLimit`.
  final List<TrackListItem> songs;

  /// Every song that matched, which can be more than [songs].
  final int songTotal;
  final List<AlbumSummary> albums;
  final List<ArtistSummary> artists;

  bool get isEmpty => songTotal == 0 && albums.isEmpty && artists.isEmpty;
}

/// The three groups for the query [termsKey] (see [searchSongsProvider]).
/// Loading until each has a first result; keeps results through a failed or
/// running reload, and is an error only when one failed with nothing to show.
final searchResultsProvider = Provider.autoDispose
    .family<AsyncValue<SearchResults>, String>((ref, termsKey) {
      final songs = ref.watch(searchSongsProvider(termsKey));
      final albums = ref.watch(searchAlbumIndexProvider);
      final artists = ref.watch(searchArtistIndexProvider);
      final song = songs.value;
      final albumIndex = albums.value;
      final artistIndex = artists.value;
      if (song == null || albumIndex == null || artistIndex == null) {
        final failed = [songs, albums, artists].where((a) => a.hasError);
        if (failed.isEmpty) return const AsyncLoading();
        final e = failed.first;
        return AsyncError(e.error!, e.stackTrace ?? StackTrace.empty);
      }
      final terms = termsKey.split(' ');
      return AsyncData(
        SearchResults(
          songs: song.songs,
          songTotal: song.total,
          albums: albumIndex.match(terms),
          artists: buildArtistSummaries(artistIndex.match(terms)),
        ),
      );
    });
