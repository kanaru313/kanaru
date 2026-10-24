import 'library_database.dart';

/// One row per artist key with an album cover: the cover of the first of
/// its albums that has one, in the order of the artist page tiles. Albums
/// the artist owns (its key is one of the album key's artist keys) come
/// before those it appears on; then year (unknown last), title sort key and
/// album key. Each album is aggregated over all its tracks, like
/// `albumColumns`, so year and cover match the album tile.
///
/// Albums not told apart by artist have an empty artist key and count as
/// appeared on here, while the artist page may still list them as owned.
const artistCoversSql =
    '''
WITH albums(ak, tk, year, sort, cover) AS (
  SELECT album_artist_key, album_title_key, max(year), min(album_sort),
    min(cover_key)
  FROM tracks WHERE album_title_key IS NOT NULL
  GROUP BY album_artist_key, album_title_key),
credited(k, ak, tk) AS (
  SELECT DISTINCT ta.artist_key, t.album_artist_key, t.album_title_key
  FROM track_artists AS ta JOIN tracks AS t ON t.id = ta.track_id
  WHERE t.album_title_key IS NOT NULL),
ranked(k, cover, rn) AS (
  SELECT c.k, a.cover, row_number() OVER (
    PARTITION BY c.k ORDER BY
      instr('$_sep' || c.ak || '$_sep', '$_sep' || c.k || '$_sep') = 0,
      a.year IS NULL, a.year, a.sort, c.ak, c.tk)
  FROM credited AS c JOIN albums AS a ON a.ak = c.ak AND a.tk = c.tk
  WHERE a.cover IS NOT NULL)
SELECT k, cover FROM ranked WHERE rn = 1''';

const _sep = albumArtistKeySeparator;

/// Covers shown for artists, who have no pictures of their own.
extension ArtistCoverQueries on LibraryDatabase {
  /// Cover key by artist key (see [artistCoversSql]); artists without any
  /// album cover are missing.
  Future<Map<String, String>> artistCovers() async {
    final rows = await customSelect(
      artistCoversSql,
      readsFrom: {tracks, trackArtists},
    ).get();
    return {
      for (final row in rows) row.read<String>('k'): row.read<String>('cover'),
    };
  }
}
