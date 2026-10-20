import 'package:drift/drift.dart';

import 'library_database.dart';
import 'library_sql_functions.dart' show artistKeysDelimiter;

// The kanaru_* functions come from `registerLibrarySqlFunctions`: every key
// is made by the Dart rules in `artist_names.dart`, never by SQL's lower().
// Calling Dart from SQL costs a few microseconds, so the queries first
// group tracks by their distinct tag values natively and call the
// functions once per distinct value, not once per track. `LIMIT -1` keeps
// SQLite from pushing a function filter down into such a subquery.

/// Album key, artist part.
const albumArtistKeySql = 'kanaru_album_artist_key(album_artist, artist)';

/// Album key, title part.
const albumTitleKeySql = 'kanaru_album_title_key(album)';

/// Disc then track, unknown numbers last; shared by the album and artist
/// pages so both list an album the same way.
const discTrackOrderSql =
    'disc_no IS NULL, disc_no, track_no IS NULL, track_no, '
    'title COLLATE NOCASE, id';

const albumsSql =
    '''
SELECT ak, tk, min(title) AS title, min(artist) AS artist, max(year) AS year,
  sum(n) AS n, sum(duration) AS duration, max(added) AS added
FROM (
  SELECT $albumArtistKeySql AS ak, $albumTitleKeySql AS tk, album AS title,
    coalesce(album_artist, kanaru_first_artist(artist)) AS artist,
    year, n, duration, added
  FROM (
    SELECT album_artist, artist, album, max(year) AS year, count(*) AS n,
      sum(duration_ms) AS duration, max(added_at) AS added
    FROM tracks WHERE album IS NOT NULL
    GROUP BY album_artist, artist, album
    LIMIT -1
  )
)
GROUP BY ak, tk''';

/// Per exact `artist` value: its album keys joined by char(30), each key's
/// two parts joined by char(31), without repeats. The feature splits the
/// value into names with the same Dart rules.
const artistCreditsSql =
    '''
SELECT artist, sum(n) AS n, group_concat(album_key, char(30)) AS album_keys
FROM (
  SELECT artist, sum(n) AS n, album_key
  FROM (
    SELECT artist, n,
      CASE WHEN album IS NOT NULL
        THEN $albumArtistKeySql || char(31) || $albumTitleKeySql
      END AS album_key
    FROM (
      SELECT artist, album_artist, album, count(*) AS n
      FROM tracks WHERE artist IS NOT NULL
      GROUP BY artist, album_artist, album
      LIMIT -1
    )
  )
  GROUP BY artist, album_key
)
GROUP BY artist''';

/// The columns of a [BrowseTrack], from `tracks AS t`; keys are computed
/// only for the rows returned.
const _browseTrackColumns = '''
t.id, t.path, t.title, t.artist, t.album, t.album_artist, t.year, t.disc_no,
t.track_no, t.duration_ms,
CASE WHEN t.album IS NOT NULL
  THEN kanaru_album_artist_key(t.album_artist, t.artist) END AS ak,
CASE WHEN t.album IS NOT NULL THEN kanaru_album_title_key(t.album) END AS tk''';

/// `?1`, `?2`: the parts of an [AlbumKey]. Finds the distinct
/// (album artist, artist, album) values with that key, then their tracks.
const albumTracksSql =
    '''
SELECT $_browseTrackColumns
FROM tracks AS t JOIN (
  SELECT album_artist, artist, album
  FROM (
    SELECT DISTINCT album_artist, artist, album
    FROM tracks WHERE album IS NOT NULL
    LIMIT -1
  )
  WHERE $albumTitleKeySql = ?2 AND $albumArtistKeySql = ?1
) AS c ON t.album = c.album AND t.album_artist IS c.album_artist
  AND t.artist IS c.artist
ORDER BY $discTrackOrderSql''';

/// `?1`: an artist key. Matches whole names in `artist` only (not
/// `album_artist`); `instr` instead of `LIKE` so `%` and `_` are literal.
const artistTracksSql =
    '''
SELECT $_browseTrackColumns FROM tracks AS t
WHERE t.artist IN (
  SELECT artist
  FROM (
    SELECT DISTINCT artist FROM tracks WHERE artist IS NOT NULL LIMIT -1
  )
  WHERE instr(kanaru_artist_keys(artist),
    '$artistKeysDelimiter' || ?1 || '$artistKeysDelimiter') > 0
)
ORDER BY year IS NULL, year, tk IS NULL, tk, ak, $discTrackOrderSql''';

/// ORDER BY of the Songs list. Unknown values go last in both directions;
/// [descending] flips only the main key; ties fall back to title then id.
String songsOrderSql(SongOrder order, {bool descending = false}) {
  final dir = descending ? 'DESC' : 'ASC';
  const tail = 'title COLLATE NOCASE, id';
  return switch (order) {
    SongOrder.title => 'title COLLATE NOCASE $dir, id',
    SongOrder.artist => 'artist IS NULL, artist COLLATE NOCASE $dir, $tail',
    SongOrder.album => 'album IS NULL, album COLLATE NOCASE $dir, $tail',
    SongOrder.year => 'year IS NULL, year $dir, $tail',
    SongOrder.dateAdded => 'added_at $dir, $tail',
    SongOrder.duration => 'duration_ms IS NULL, duration_ms $dir, $tail',
  };
}

/// Queries for browsing the library by album and artist, and the sortable
/// Songs list. Every one re-runs when `tracks` changes.
extension LibraryBrowseQueries on LibraryDatabase {
  /// Every album with a title, in no particular order.
  Stream<List<AlbumSummary>> watchAlbums() => _albums().watch();

  /// [watchAlbums] once, for a throttled refresh.
  Future<List<AlbumSummary>> albums() => _albums().get();

  /// One row per distinct `artist` value; the feature splits them into names.
  Stream<List<ArtistCredit>> watchArtistCredits() => _artistCredits().watch();

  /// [watchArtistCredits] once, for a throttled refresh.
  Future<List<ArtistCredit>> artistCredits() => _artistCredits().get();

  Selectable<AlbumSummary> _albums() => _query(albumsSql, const [], (row) {
    return AlbumSummary(
      key: AlbumKey(row.read<String>('ak'), row.read<String>('tk')),
      title: row.read<String>('title'),
      artist: row.readNullable<String>('artist'),
      year: row.readNullable<int>('year'),
      trackCount: row.read<int>('n'),
      durationMs: row.readNullable<int>('duration'),
      addedAt: row.read<int>('added'),
    );
  });

  Selectable<ArtistCredit> _artistCredits() =>
      _query(artistCreditsSql, const [], (row) {
        final keys = row.readNullable<String>('album_keys');
        return ArtistCredit(
          artist: row.read<String>('artist'),
          trackCount: row.read<int>('n'),
          albumKeys: {
            if (keys != null)
              for (final key in keys.split('\u001e')) _parseAlbumKey(key),
          },
        );
      });

  /// The tracks of one album, by disc then track.
  Stream<List<BrowseTrack>> watchAlbumTracks(AlbumKey key) =>
      _albumTracks(key).watch();

  /// [watchAlbumTracks] once, for a throttled refresh.
  Future<List<BrowseTrack>> albumTracks(AlbumKey key) =>
      _albumTracks(key).get();

  /// The tracks crediting [artistKey] (see `artistKey` in
  /// `artist_names.dart`), by year, album, disc and track.
  Stream<List<BrowseTrack>> watchArtistTracks(String artistKey) =>
      _artistTracks(artistKey).watch();

  /// [watchArtistTracks] once, for a throttled refresh.
  Future<List<BrowseTrack>> artistTracks(String artistKey) =>
      _artistTracks(artistKey).get();

  Selectable<BrowseTrack> _albumTracks(AlbumKey key) => _query(albumTracksSql, [
    Variable(key.artistKey),
    Variable(key.titleKey),
  ], _browseTrack);

  Selectable<BrowseTrack> _artistTracks(String artistKey) =>
      _query(artistTracksSql, [Variable(artistKey)], _browseTrack);

  /// All tracks for the Songs list. The default order is the same as
  /// [LibraryDatabase.watchTrackListItems].
  Stream<List<TrackListItem>> watchSongs({
    SongOrder order = SongOrder.title,
    bool descending = false,
  }) => _songs(order, descending).watch();

  /// [watchSongs] once, for a throttled refresh.
  Future<List<TrackListItem>> songs({
    SongOrder order = SongOrder.title,
    bool descending = false,
  }) => _songs(order, descending).get();

  Selectable<TrackListItem> _songs(SongOrder order, bool descending) => _query(
    'SELECT id, path, title, artist, album, duration_ms FROM tracks '
    'ORDER BY ${songsOrderSql(order, descending: descending)}',
    const [],
    (row) => TrackListItem(
      id: row.read<int>('id'),
      path: row.read<String>('path'),
      title: row.read<String>('title'),
      artist: row.readNullable<String>('artist'),
      album: row.readNullable<String>('album'),
      durationMs: row.readNullable<int>('duration_ms'),
    ),
  );

  Selectable<T> _query<T>(
    String sql,
    List<Variable> variables,
    T Function(QueryRow row) map,
  ) => customSelect(sql, variables: variables, readsFrom: {tracks}).map(map);
}

AlbumKey _parseAlbumKey(String joined) {
  final split = joined.indexOf('\u001f');
  return AlbumKey(joined.substring(0, split), joined.substring(split + 1));
}

BrowseTrack _browseTrack(QueryRow row) {
  final titleKey = row.readNullable<String>('tk');
  return BrowseTrack(
    id: row.read<int>('id'),
    path: row.read<String>('path'),
    title: row.read<String>('title'),
    artist: row.readNullable<String>('artist'),
    album: row.readNullable<String>('album'),
    albumArtist: row.readNullable<String>('album_artist'),
    year: row.readNullable<int>('year'),
    discNo: row.readNullable<int>('disc_no'),
    trackNo: row.readNullable<int>('track_no'),
    durationMs: row.readNullable<int>('duration_ms'),
    albumKey: titleKey == null
        ? null
        : AlbumKey(row.read<String>('ak'), titleKey),
  );
}
