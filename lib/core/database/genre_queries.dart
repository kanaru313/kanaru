import 'package:drift/drift.dart';

import 'library_browse_queries.dart';
import 'library_database.dart';
import 'playlist_cover_keys.dart';

/// `?1`..: the stored genre strings. The albums holding at least one track
/// of them (with [includeNull], also of tracks with no genre at all), each
/// aggregated over all its tracks (not only the genre's).
String genreAlbumsSql(int rawCount, {bool includeNull = false}) =>
    '''
SELECT $albumColumns
FROM tracks WHERE album_title_key IS NOT NULL AND
  (album_artist_key, album_title_key) IN (
    SELECT album_artist_key, album_title_key FROM tracks
    WHERE ${_genreCondition('genre', rawCount, includeNull)}
      AND album_title_key IS NOT NULL)
$albumGroupSql''';

String genreTracksSql(int rawCount, {bool includeNull = false}) =>
    '''
SELECT $browseTrackColumns FROM tracks AS t
WHERE ${_genreCondition('t.genre', rawCount, includeNull)}
ORDER BY t.title_sort, t.id''';

/// Whether [column] is one of the [rawCount] strings (`?`s), or null when
/// [includeNull]; never true when it asks for neither.
String _genreCondition(String column, int rawCount, bool includeNull) {
  final parts = [
    if (rawCount > 0) '$column IN (${_placeholders(rawCount)})',
    if (includeNull) '$column IS NULL',
  ];
  return parts.isEmpty ? '0' : '(${parts.join(' OR ')})';
}

String _placeholders(int count) => List.filled(count, '?').join(', ');

/// Queries for browsing the library by genre. A genre is a set of stored
/// `genre` strings (see `splitGenres` in `genre_names.dart`), so the page
/// queries take those raw strings. They run once per call; a screen that
/// follows `tracks` wraps them in `throttledTracksQuery`.
extension GenreQueries on LibraryDatabase {
  /// Every stored genre string with the tracks holding it; the group of
  /// tracks without a genre has a null `raw`.
  Future<List<({String? raw, int count})>> genreCounts() =>
      customSelect(
            'SELECT genre, count(*) AS n FROM tracks GROUP BY genre',
            readsFrom: {tracks},
          )
          .map(
            (row) => (
              raw: row.readNullable<String>('genre'),
              count: row.read<int>('n'),
            ),
          )
          .get();

  /// The tracks whose genre string is one of [raws] (or, with [includeNull],
  /// that have none), by title.
  Future<List<BrowseTrack>> genreTracks(
    List<String> raws, {
    bool includeNull = false,
  }) => raws.isEmpty && !includeNull
      ? Future.value(const [])
      : customSelect(
          genreTracksSql(raws.length, includeNull: includeNull),
          variables: [for (final raw in raws) Variable(raw)],
          readsFrom: {tracks},
        ).map(browseTrackFromRow).get();

  /// Up to [playlistCollageSize] distinct cover keys for the genre tile
  /// collage: the most recently added tracks whose genre string is one of
  /// [raws] (or, with [includeNull], that has none).
  Future<List<String>> genreCoverKeys(
    List<String> raws, {
    bool includeNull = false,
  }) => raws.isEmpty && !includeNull
      ? Future.value(const [])
      : customSelect(
          '''
SELECT cover_key FROM tracks
WHERE ${_genreCondition('genre', raws.length, includeNull)}
  AND cover_key IS NOT NULL
ORDER BY added_at DESC, id DESC
LIMIT $playlistCollageScanLimit''',
          variables: [for (final raw in raws) Variable(raw)],
          readsFrom: {tracks},
        ).map((row) => row.read<String>('cover_key')).get().then(
          pickCollageKeys,
        );

  /// The albums with a track whose genre string is one of [raws] (or, with
  /// [includeNull], that has none), in no particular order.
  Future<List<AlbumSummary>> genreAlbums(
    List<String> raws, {
    bool includeNull = false,
  }) => raws.isEmpty && !includeNull
      ? Future.value(const [])
      : customSelect(
          genreAlbumsSql(raws.length, includeNull: includeNull),
          variables: [for (final raw in raws) Variable(raw)],
          readsFrom: {tracks},
        ).map(albumSummaryFromRow).get();
}
