import 'package:drift/drift.dart';

import 'library_browse_queries.dart';
import 'library_database.dart';

/// `?1`..: the stored genre strings. The albums holding at least one track
/// of them, each aggregated over all its tracks (not only the genre's).
String genreAlbumsSql(int rawCount) =>
    '''
SELECT $albumColumns
FROM tracks WHERE album_title_key IS NOT NULL AND
  (album_artist_key, album_title_key) IN (
    SELECT album_artist_key, album_title_key FROM tracks
    WHERE genre IN (${_placeholders(rawCount)}) AND album_title_key IS NOT NULL)
$albumGroupSql''';

String genreTracksSql(int rawCount) =>
    '''
SELECT $browseTrackColumns FROM tracks AS t
WHERE t.genre IN (${_placeholders(rawCount)})
ORDER BY t.title_sort, t.id''';

String _placeholders(int count) => List.filled(count, '?').join(', ');

/// Queries for browsing the library by genre. A genre is a set of stored
/// `genre` strings (see `splitGenres` in `genre_names.dart`), so the page
/// queries take those raw strings. They run once per call; a screen that
/// follows `tracks` wraps them in `throttledTracksQuery`.
extension GenreQueries on LibraryDatabase {
  /// Every stored genre string with the tracks holding it. Tracks without a
  /// genre are left out.
  Future<List<({String raw, int count})>> genreCounts() =>
      customSelect(
            'SELECT genre, count(*) AS n FROM tracks WHERE genre IS NOT NULL '
            'GROUP BY genre',
            readsFrom: {tracks},
          )
          .map(
            (row) =>
                (raw: row.read<String>('genre'), count: row.read<int>('n')),
          )
          .get();

  /// The tracks whose genre string is one of [raws], by title.
  Future<List<BrowseTrack>> genreTracks(List<String> raws) => raws.isEmpty
      ? Future.value(const [])
      : customSelect(
          genreTracksSql(raws.length),
          variables: [for (final raw in raws) Variable(raw)],
          readsFrom: {tracks},
        ).map(browseTrackFromRow).get();

  /// The albums with a track whose genre string is one of [raws], in no
  /// particular order.
  Future<List<AlbumSummary>> genreAlbums(List<String> raws) => raws.isEmpty
      ? Future.value(const [])
      : customSelect(
          genreAlbumsSql(raws.length),
          variables: [for (final raw in raws) Variable(raw)],
          readsFrom: {tracks},
        ).map(albumSummaryFromRow).get();
}
