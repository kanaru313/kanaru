import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_search_queries.dart';
import '../../core/database/library_startup.dart';
import '../../core/database/search_language_values.dart';
import '../../core/database/search_file_text_index.dart';
import '../../core/database/throttled_tracks_query.dart';
import '../../core/search/search_fields.dart';
import '../../core/search/search_prefs_provider.dart';
import '../../core/search/search_query.dart';
import '../../core/search/typo_correction.dart';
import '../../shared/artist_summaries.dart';
import '../../shared/library_browse_refresh.dart';
import 'search_providers.dart';
import 'search_typo_providers.dart';

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

/// The distinct raw language tags of the library, reloaded (throttled) while
/// it changes. Only watched by searches that use `language:`, so typing other
/// queries never reads it, and typing more of a query reuses the cached list.
/// A reload that finds the same tags emits nothing, so the song searches
/// watching it are not rebuilt.
final searchLanguagesProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return Stream.value(const []);
  return throttledTracksQuery(
    db,
    () => loadDistinctLanguages(db),
    interval: ref.watch(libraryBrowseRefreshIntervalProvider),
  ).distinct(_sameTags);
});

/// Whether [a] and [b] hold the same tags, whatever their order.
bool _sameTags(List<String> a, List<String> b) =>
    listEquals([...a]..sort(), [...b]..sort());

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
      List<String>? languages;
      if (request.query.languages.isNotEmpty) {
        final distinct = ref.watch(searchLanguagesProvider);
        languages = distinct.value;
        if (languages == null) {
          if (distinct.hasError) {
            return Stream.error(distinct.error!, distinct.stackTrace);
          }
          return const Stream.empty();
        }
      }
      return throttledTracksQuery(
        db,
        () => db.searchSongsFor(
          request,
          extraIds: extraIds,
          distinctLanguages: languages,
        ),
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
      var song = songs.requireValue;
      var albumList = albums?.requireValue.match(free) ?? const [];
      var artistList = artists?.requireValue.match(free) ?? const [];
      var corrections = const <String, String>{};
      // Few songs: try again with the misspelt words fixed, real matches
      // first. Waits for the dictionary; goes on without it if it fails
      // (a failed reload keeps the dictionary it had).
      final needsVocabulary =
          song.total < typoRetryBelow && hasCorrectableWord(request);
      if (needsVocabulary) {
        ref.listen(searchVocabularyProvider, logVocabularyFailure);
        final vocab = ref.watch(searchVocabularyProvider);
        final dictionary = vocab.value;
        if (dictionary == null && !vocab.hasError) {
          return const AsyncLoading();
        }
        final files = free.isNotEmpty && usesFileText(fields)
            ? ref.watch(searchFileTextIndexProvider).value
            : null;
        final fix = dictionary == null
            ? null
            : ref.watch(
                searchTypoCorrectionProvider((request, dictionary, files)),
              );
        if (fix != null) {
          final fixed = ref.watch(searchSongsProvider(fix.request));
          if (fixed.value == null && !fixed.hasError) {
            return const AsyncLoading();
          }
          final fixedFree = fix.request.query.freeTerms;
          final mergedSongs = fixed.value == null
              ? song
              : mergeCorrectedSongs(song, fixed.requireValue);
          final mergedAlbums = albums == null
              ? albumList
              : _union(
                  albumList,
                  albums.requireValue.match(fixedFree),
                  (a) => a.key,
                );
          final mergedArtists = artists == null
              ? artistList
              : _union(
                  artistList,
                  artists.requireValue.match(fixedFree),
                  (a) => a.key,
                );
          if (!identical(mergedSongs, song) ||
              mergedAlbums.length != albumList.length ||
              mergedArtists.length != artistList.length) {
            song = mergedSongs;
            albumList = mergedAlbums;
            artistList = mergedArtists;
            corrections = fix.replacements;
          }
        }
      }
      return AsyncData(
        SearchResults(
          songs: song.songs,
          songTotal: song.total,
          albums: albumList,
          artists: buildArtistSummaries(artistList),
          corrections: corrections,
          needsVocabulary: needsVocabulary,
        ),
      );
    });

/// [first] then the items of [second] whose key it lacks.
List<T> _union<T, K>(List<T> first, List<T> second, K Function(T) key) {
  final have = {for (final t in first) key(t)};
  return [
    ...first,
    for (final t in second)
      if (have.add(key(t))) t,
  ];
}
