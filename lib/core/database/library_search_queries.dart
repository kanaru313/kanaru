import 'package:drift/drift.dart';
// DriftRemoteException is how errors from the database isolate arrive.
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:logging/logging.dart';
import 'package:sqlite3/common.dart' show SqliteException;

import 'library_browse_queries.dart';
import 'library_database.dart';
import 'search_terms.dart';

final _log = Logger('library.search');

/// Most songs one search returns.
const searchSongLimit = 200;

/// Ranking: the full-text score, then title. The score weights the columns
/// (title, artist, album, album artist, genre, in the order of
/// `library_search.drift`) with the title far ahead, so a title match
/// outranks the others unless the others are much better matches overall;
/// the order is weighted, not strict.
const _scoreOrder = 'score, title_sort, id';

/// For a one-character single-term query about half the library matches and
/// the score is noise, so the order is by title alone.
const _titleOrder = 'title_sort, id';

/// `?1`: the FTS query, `?2`: the limit. `total` is every match, counted
/// before the limit, in the same statement as the page so the two agree (an
/// uncorrelated subquery runs once; `count(*) OVER ()` forced a sort of
/// every match and cost +50% on broad queries).
String _songsSql(String order) =>
    '''
SELECT $songColumns, (SELECT count(*) FROM track_search
        WHERE track_search MATCH ?1) AS total FROM tracks
JOIN (SELECT rowid AS hit, bm25(track_search, 20.0, 2.0, 1.5, 1.0, 0.5) AS score
      FROM track_search WHERE track_search MATCH ?1) ON id = hit
ORDER BY $order LIMIT ?2''';

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
  ///
  /// A corrupt index (for example after a SQLite upgrade changed how text is
  /// split) is rebuilt once per database and the search retried.
  Future<SongSearchResult> searchSongs(
    List<String> terms, {
    int limit = searchSongLimit,
  }) async {
    if (terms.isEmpty) return SongSearchResult.empty;
    assert(limit > 0, 'limit must be positive');
    final fts = ftsPrefixQuery(terms);
    final order = terms.length == 1 && terms.first.runes.length == 1
        ? _titleOrder
        : _scoreOrder;
    // In SQLite a negative LIMIT means no limit, so never pass less than 1.
    final cap = limit < 1 ? 1 : limit;
    try {
      return await _searchSongs(fts, order, cap);
    } catch (error) {
      if (!_isCorruption(error)) rethrow;
      final repair = _repairs[this] ??= _rebuildIndex(error);
      await repair;
      return _searchSongs(fts, order, cap); // a second corruption propagates
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

  Future<SongSearchResult> _searchSongs(
    String fts,
    String order,
    int limit,
  ) async {
    final rows = await customSelect(
      _songsSql(order),
      variables: [Variable.withString(fts), Variable.withInt(limit)],
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
