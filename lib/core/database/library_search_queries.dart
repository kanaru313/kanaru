import 'package:drift/drift.dart';
// DriftRemoteException is how errors from the database isolate arrive.
// ignore: experimental_member_use
import 'package:drift/remote.dart' show DriftRemoteException;
import 'package:logging/logging.dart';
import 'package:sqlite3/common.dart' show SqliteException;

import 'library_browse_queries.dart';
import 'library_database.dart';
import 'search_terms.dart';

final _log = Logger('library.search');

/// Most songs one search returns.
const searchSongLimit = 200;

/// Ranking: the full-text score (title, artist, album, album artist, genre
/// weights, in the column order of `library_search.drift`), then title. If
/// scoring ever costs too much on a large library, `title_sort, id` alone
/// is the cheaper order.
const _songOrder = 'score, title_sort, id';

/// `?1`: the FTS query, `?2`: the limit.
const _songsSql =
    '''
SELECT $songColumns FROM tracks
JOIN (SELECT rowid AS hit, bm25(track_search, 10.0, 5.0, 3.0, 2.0, 1.0) AS score
      FROM track_search WHERE track_search MATCH ?1) ON id = hit
ORDER BY $_songOrder LIMIT ?2''';

const _countSql =
    'SELECT count(*) AS n FROM track_search WHERE track_search MATCH ?1';

/// The best songs of a search and how many matched in all.
class SongSearchResult {
  const SongSearchResult({required this.songs, required this.total});

  static const empty = SongSearchResult(songs: [], total: 0);

  final List<TrackListItem> songs;

  /// Every match, which can be more than [songs].
  final int total;
}

/// Databases whose index was rebuilt after a corruption error, so a
/// persistent fault is reported instead of rebuilt on every keystroke.
final _rebuilt = Expando<bool>('searchIndexRebuilt');

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
    final fts = ftsPrefixQuery(terms);
    try {
      return await _searchSongs(fts, limit);
    } catch (error) {
      if (!_isCorruption(error) || _rebuilt[this] == true) rethrow;
      _log.warning('Search index is corrupt; rebuilding it', error);
      _rebuilt[this] = true;
      await customStatement(
        "INSERT INTO track_search(track_search) VALUES ('rebuild')",
      );
      return _searchSongs(fts, limit);
    }
  }

  Future<SongSearchResult> _searchSongs(String fts, int limit) async {
    final Set<ResultSetImplementation> reads = {tracks, trackSearch};
    final page = await customSelect(
      _songsSql,
      variables: [Variable.withString(fts), Variable.withInt(limit)],
      readsFrom: reads,
    ).map(trackListItemFromRow).get();
    final count = await customSelect(
      _countSql,
      variables: [Variable.withString(fts)],
      readsFrom: reads,
    ).getSingle();
    return SongSearchResult(songs: page, total: count.read<int>('n'));
  }
}

/// SQLITE_CORRUPT (11) in any of its extended forms, which FTS5 reports as
/// "database disk image is malformed". Through the database isolate the
/// exception arrives wrapped.
bool _isCorruption(Object error) {
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  return cause is SqliteException && cause.extendedResultCode & 0xff == 11;
}
