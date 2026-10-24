import 'library_browse_queries.dart' show albumColumns;

// SQL of the Home page reads. Public only so the plan test can EXPLAIN it.
// Track columns carry the `t.` prefix: `play_stats` also has a `path`.
//
// Every query that starts from listens must drive from `play_stats` or the
// `plays_played_at` range and look `tracks` up by its unique `path` index.
// `play_stats` has no index on `last_played_at`, so the recent lists scan it
// and sort: fine for the page sizes used, an index would need a schema change.

// The album and artist CTEs use CROSS JOIN: SQLite keeps the written table
// order for it, so `play_stats` stays the outer loop and `tracks` and
// `track_artists` are searched by index. Without `sqlite_stat1` (real
// databases are never ANALYZEd) the planner may otherwise put `tracks` first
// and scan it.

const _trackColumns =
    't.id, t.path, t.title, t.artist, t.album, t.duration_ms, t.cover_key';

/// `?1` limit, `?2` offset. One row per played track still in the library.
const homeRecentlyPlayedSql =
    '''
SELECT $_trackColumns
FROM play_stats AS s JOIN tracks AS t ON t.path = s.path
ORDER BY s.last_played_at DESC, s.path
LIMIT ?1 OFFSET ?2''';

/// `?1` oldest `added_at` (null: no bound), `?2` limit, `?3` offset. The bound
/// is `>= coalesce(?1, min)` and not `?1 IS NULL OR ...`: an `OR` over the
/// parameter hides the range from the planner, which then scans `tracks`;
/// this way it walks `tracks_added_at` from the newest row.
const homeRecentlyAddedSql =
    '''
SELECT $_trackColumns
FROM tracks AS t
WHERE t.added_at >= coalesce(?1, -9223372036854775808)
ORDER BY t.added_at DESC, t.mtime_ms DESC, t.id DESC
LIMIT ?2 OFFSET ?3''';

/// `?1` start, `?2` end (half-open), `?3` limit, `?4` offset. The inner join
/// to `tracks` sits inside the paged subquery, so a track gone from the
/// library never shifts the offset.
const homeMemoriesSql =
    '''
SELECT $_trackColumns
FROM (SELECT p.path AS path, count(*) AS n, max(p.played_at) AS last
      FROM plays AS p JOIN tracks AS k ON k.path = p.path
      WHERE p.played_at >= ?1 AND p.played_at < ?2
      GROUP BY p.path ORDER BY n DESC, last DESC, p.path
      LIMIT ?3 OFFSET ?4) AS a
JOIN tracks AS t ON t.path = a.path
ORDER BY a.n DESC, a.last DESC, a.path''';

/// `?1` limit, `?2` offset. `r` picks the albums by their latest listen, then
/// each album is aggregated over all its tracks, like the Albums grid.
const homeRecentAlbumsSql =
    '''
WITH r(rak, rtk, last) AS (
  SELECT t.album_artist_key, t.album_title_key, max(s.last_played_at)
  FROM play_stats AS s CROSS JOIN tracks AS t ON t.path = s.path
  WHERE t.album_title_key IS NOT NULL
  GROUP BY t.album_artist_key, t.album_title_key
  ORDER BY 3 DESC, 1, 2
  LIMIT ?1 OFFSET ?2)
SELECT $albumColumns
FROM r JOIN tracks ON album_artist_key = r.rak AND album_title_key = r.rtk
GROUP BY r.rak, r.rtk
ORDER BY r.last DESC, r.rak, r.rtk''';

/// `?1` limit, `?2` offset. Name, track and album counts use every
/// `track_artists` row of the key, the same formula as `artistCreditsSql`, so
/// the numbers match the Artists tab.
const homeRecentArtistsSql = '''
WITH r(k, last) AS (
  SELECT ta.artist_key, max(s.last_played_at)
  FROM play_stats AS s CROSS JOIN tracks AS t ON t.path = s.path
    CROSS JOIN track_artists AS ta ON ta.track_id = t.id
  GROUP BY ta.artist_key
  ORDER BY 2 DESC, 1
  LIMIT ?1 OFFSET ?2)
SELECT r.k AS artist_key,
  (SELECT min(artist_name) FROM track_artists WHERE artist_key = r.k) AS name,
  (SELECT count(*) FROM track_artists WHERE artist_key = r.k) AS n,
  (SELECT count(DISTINCT u.album_artist_key || char(31) || u.album_title_key)
   FROM track_artists AS ua JOIN tracks AS u ON u.id = ua.track_id
   WHERE ua.artist_key = r.k) AS albums
FROM r
ORDER BY r.last DESC, r.k''';
