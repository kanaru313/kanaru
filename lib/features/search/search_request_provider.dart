import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_search_queries.dart';
import '../../core/database/library_startup.dart';
import '../../core/database/search_file_text_index.dart';
import '../../core/database/throttled_tracks_query.dart';
import '../../core/search/search_fields.dart';
import '../../core/search/search_prefs_provider.dart';
import '../../core/search/search_query.dart';
import '../../shared/artist_summaries.dart';
import '../../shared/library_browse_refresh.dart';
import 'search_providers.dart';

/// Whether [a] and [b] hold the same fields.
bool sameSearchFields(Set<SearchField> a, Set<SearchField> b) =>
    a.length == b.length && a.containsAll(b);

/// Whether [fields] are the default choice (the "all" preset).
bool isDefaultSearchFields(Set<SearchField> fields) =>
    sameSearchFields(fields, defaultSearchFields);

/// The fields the free text looks at. The default (all tag fields) until the
/// saved choice has loaded, so the page never waits for the file.
final searchFieldsProvider = Provider.autoDispose<Set<SearchField>>(
  (ref) => ref.watch(
    searchPrefsProvider.select((p) => p.value?.fields ?? defaultSearchFields),
  ),
);

/// The words of file names and comments, loaded like the name indexes
/// (throttled reloads). Only watched when a search asks for those fields.
final searchFileTextIndexProvider =
    StreamProvider.autoDispose<SearchFileTextIndex>((ref) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return const Stream.empty();
      return throttledTracksQuery(
        db,
        () => SearchFileTextIndex.load(db),
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      );
    });

/// The best songs for a request. Reloaded (throttled) while the library
/// changes. Stays loading until the file text index is ready when the request
/// looks at file names or comments.
final searchSongsProvider = StreamProvider.autoDispose
    .family<SongSearchResult, SearchRequest>((ref, request) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(SongSearchResult.empty);
      var extraIds = const <int>[];
      final free = request.query.freeTerms;
      if (free.isNotEmpty && usesFileText(request.fields)) {
        final index = ref.watch(searchFileTextIndexProvider);
        final loaded = index.value;
        if (loaded == null) {
          if (index.hasError) {
            return Stream.error(index.error!, index.stackTrace);
          }
          return const Stream.empty();
        }
        extraIds = loaded.match(
          free,
          fileName: request.fields.contains(SearchField.fileName),
          comment: request.fields.contains(SearchField.comment),
        );
      }
      return throttledTracksQuery(
        db,
        () => db.searchSongsFor(request, extraIds: extraIds),
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      );
    });

/// The three groups for [request]. Albums need free words and the album or
/// album artist field; artists need free words and the artist field; the
/// field and filter prefixes narrow songs only. Loading until each group
/// shown has a first result; keeps results through a failed or running
/// reload, and is an error only when one failed with nothing to show.
final searchResultsProvider = Provider.autoDispose
    .family<AsyncValue<SearchResults>, SearchRequest>((ref, request) {
      final free = request.query.freeTerms;
      final fields = request.fields;
      final songs = ref.watch(searchSongsProvider(request));
      final albums =
          free.isNotEmpty &&
              (fields.contains(SearchField.album) ||
                  fields.contains(SearchField.albumArtist))
          ? ref.watch(searchAlbumIndexProvider)
          : null;
      final artists = free.isNotEmpty && fields.contains(SearchField.artist)
          ? ref.watch(searchArtistIndexProvider)
          : null;
      final needed = [songs, ?albums, ?artists];
      if (needed.any((a) => a.value == null)) {
        final failed = needed.where((a) => a.hasError);
        if (failed.isEmpty) return const AsyncLoading();
        final e = failed.first;
        return AsyncError(e.error!, e.stackTrace ?? StackTrace.empty);
      }
      final song = songs.requireValue;
      return AsyncData(
        SearchResults(
          songs: song.songs,
          songTotal: song.total,
          albums: albums?.requireValue.match(free) ?? const [],
          artists: artists == null
              ? const []
              : buildArtistSummaries(artists.requireValue.match(free)),
        ),
      );
    });
