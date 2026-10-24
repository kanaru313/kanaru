import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../core/database/library_search_queries.dart';
import '../../core/database/library_startup.dart';
import '../../core/database/search_file_text_index.dart';
import '../../core/database/search_vocabulary.dart';
import '../../core/database/throttled_tracks_query.dart';
import '../../core/search/search_fields.dart';
import '../../core/search/search_query.dart';
import '../../core/search/typo_correction.dart';
import '../../shared/library_browse_refresh.dart';

final _log = Logger('library.search');

/// The words of the library for correcting typos. Loaded the first time a
/// search finds few songs, then reloaded (throttled) while the library
/// changes; empty when the library is unavailable.
final searchVocabularyProvider = StreamProvider.autoDispose<TypoDictionary>((
  ref,
) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return Stream.value(TypoDictionary(const []));
  return throttledTracksQuery(
    db,
    () async => TypoDictionary(await db.searchVocabulary()),
    interval: ref.watch(libraryBrowseRefreshIntervalProvider),
  );
});

/// What [searchTypoCorrectionProvider] is computed from: the request, the
/// dictionary (by identity) and, when the request looks at file names or
/// comments, the index of their words.
typedef TypoCorrectionKey = (
  SearchRequest,
  TypoDictionary,
  SearchFileTextIndex?,
);

/// The corrected request for a [TypoCorrectionKey], computed once: a reload
/// of the songs while the dictionary is the same does not repeat the lookup.
/// A free word that the file text index matches is not corrected.
final searchTypoCorrectionProvider = Provider.autoDispose
    .family<TypoCorrection?, TypoCorrectionKey>((ref, key) {
      final (request, dictionary, files) = key;
      final fields = request.fields;
      return correctRequest(
        request,
        dictionary,
        isKnownFreeWord: files == null || !usesFileText(fields)
            ? null
            : (word) => files
                  .match(
                    [word],
                    fileName: fields.contains(SearchField.fileName),
                    comment: fields.contains(SearchField.comment),
                  )
                  .isNotEmpty,
      );
    });

/// [real] followed by the songs of [fixed] it did not have, at most
/// `searchSongLimit`. [real] is complete when it is small (it only gets
/// merged when below `typoRetryBelow`), so the total adds the songs of
/// [fixed] that are not in it.
SongSearchResult mergeCorrectedSongs(
  SongSearchResult real,
  SongSearchResult fixed,
) {
  final have = {for (final s in real.songs) s.id};
  final added = [
    for (final s in fixed.songs)
      if (!have.contains(s.id)) s,
  ];
  if (added.isEmpty) return real;
  final overlap = fixed.songs.length - added.length;
  return SongSearchResult(
    songs: [...real.songs, ...added].take(searchSongLimit).toList(),
    total: real.total + fixed.total - overlap,
  );
}

/// Logs a dictionary load that failed, once per failure; the search goes on
/// with the last dictionary, or without correcting when there is none.
void logVocabularyFailure(
  AsyncValue<TypoDictionary>? previous,
  AsyncValue<TypoDictionary> next,
) {
  if (next.hasError && !(previous?.hasError ?? false)) {
    _log.warning(
      'Loading the search vocabulary failed',
      next.error,
      next.stackTrace,
    );
  }
}
