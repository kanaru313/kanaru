import 'dart:convert';

// DriftRemoteException is how errors from the database isolate arrive.
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:logging/logging.dart';
import 'package:sqlite3/common.dart' show SqliteException;

import 'library_browse_queries.dart';
import 'library_database.dart';
import '../search/search_fields.dart';
import '../search/search_query.dart';
import 'search_language_values.dart';
import 'search_song_sql.dart';

final _log = Logger('library.search');

/// Most songs one search returns.
const searchSongLimit = 200;

/// The best songs of a search and how many matched in all.
class SongSearchResult {
  const SongSearchResult({required this.songs, required this.total});

  static const empty = SongSearchResult(songs: [], total: 0);

  final List<TrackListItem> songs;

  /// Every match, which can be more than [songs].
  final int total;
}

/// The rebuild started for a database after a corruption error. Searches
/// that hit corruption meanwhile wait for the same rebuild, and a later one
/// does not start another, so a persistent fault is reported instead of
/// rebuilt on every keystroke.
final _repairs = Expando<Future<void>>('searchIndexRepair');

/// Full-text search over the folded tags of `tracks`.
extension LibrarySearchQueries on LibraryDatabase {
  /// Songs whose title, artist, album, album artist or genre has every term
  /// of [terms] (see `searchTerms`) as a word prefix, best first, at most
  /// [limit]. No terms, no songs.
  Future<SongSearchResult> searchSongs(
    List<String> terms, {
    int limit = searchSongLimit,
  }) => searchSongsFor(
    SearchRequest(
      query: ParsedSearchQuery(freeTerms: terms),
      fields: defaultSearchFields,
    ),
    limit: limit,
  );

  /// Songs for [request], best first, at most [limit]: the free words in the
  /// chosen tag columns, `artist:`, `album:` and `genre:` words in their own
  /// column, and the year and format filters. A song matches when every word
  /// is in the chosen tag fields, or every word is in its file name or
  /// comment ([extraIds], found with `SearchFileTextIndex`); the two are not
  /// mixed. Tag matches come first. Nothing to search for gives no songs.
  ///
  /// `language:` values match the raw tags in [distinctLanguages] (read from
  /// the library when not given; callers that search often pass a cached
  /// list). No matching tag gives no songs.
  ///
  /// A corrupt index (for example after a SQLite upgrade changed how text is
  /// split) is rebuilt once per database and the search retried.
  Future<SongSearchResult> searchSongsFor(
    SearchRequest request, {
    List<int> extraIds = const [],
    List<String>? distinctLanguages,
    int limit = searchSongLimit,
  }) async {
    assert(limit > 0, 'limit must be positive');
    final wanted = request.query.languages;
    final languageValues = wanted.isEmpty
        ? null
        : matchingLanguageValues(
            distinctLanguages ?? await loadDistinctLanguages(this),
            wanted,
          );
    final built = buildSongSearchSql(
      request,
      hasExtra: extraIds.isNotEmpty,
      limit: limit,
      extraIdsJson: jsonEncode(extraIds),
      languageValues: languageValues,
    );
    if (built == null) return SongSearchResult.empty;
    try {
      return await _searchSongs(built);
    } catch (error) {
      if (!_isCorruption(error)) rethrow;
      final repair = _repairs[this] ??= _rebuildIndex(error);
      await repair;
      return _searchSongs(built); // a second corruption propagates
    }
  }

  Future<void> _rebuildIndex(Object cause) {
    _log.warning('Search index is corrupt; rebuilding it', cause);
    return customStatement(
      "INSERT INTO track_search(track_search) VALUES ('rebuild')",
    ).catchError((Object e, StackTrace st) {
      _log.severe('Search index rebuild failed', e, st);
      throw e;
    });
  }

  Future<SongSearchResult> _searchSongs(SongSearchSql built) async {
    final rows = await customSelect(
      built.sql,
      variables: built.variables,
      readsFrom: {tracks, trackSearch},
    ).get();
    if (rows.isEmpty) return SongSearchResult.empty;
    return SongSearchResult(
      songs: [for (final row in rows) trackListItemFromRow(row)],
      total: rows.first.read<int>('total'),
    );
  }
}

/// SQLITE_CORRUPT (11) in any of its extended forms, which FTS5 reports as
/// "database disk image is malformed". Through the database isolate the
/// exception arrives wrapped.
bool _isCorruption(Object error) {
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  return cause is SqliteException && cause.extendedResultCode & 0xff == 11;
}
