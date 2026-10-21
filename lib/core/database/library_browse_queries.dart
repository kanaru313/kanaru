import 'package:drift/drift.dart';

import 'library_database.dart';

// Every query reads the keys stored by `trackKeysFor` (track_keys.dart) and
// the `track_artists` rows, so grouping and ordering are index work in SQLite
// and no Dart code runs per track.

/// The columns of an [AlbumSummary]: the shown title, artist and year are
/// aggregates over the stored columns, so the list, the album page and the
/// artist page agree whichever track order the database returns.
const _albumColumns = '''
album_artist_key AS ak, album_title_key AS tk, min(album) AS title,
  min(album_display_artist) AS artist, max(year) AS year, count(*) AS n,
  sum(duration_ms) AS duration, max(added_at) AS added,
  min(cover_key) AS cover, min(album_sort) AS title_sort''';

const _albumGroup = 'GROUP BY album_artist_key, album_title_key';

/// Albums: one row per (album artist key, album title key).
const albumsSql =
    '''
SELECT $_albumColumns
FROM tracks WHERE album_title_key IS NOT NULL
$_albumGroup''';

/// `?1`, `?2`: the parts of an [AlbumKey]. At most one row.
const albumSql =
    '''
SELECT $_albumColumns
FROM tracks WHERE album_artist_key = ?1 AND album_title_key = ?2
$_albumGroup''';

/// `?1`: an artist key. The albums holding at least one of their tracks,
/// each aggregated over all its tracks (not only the artist's).
const artistAlbumsSql =
    '''
SELECT $_albumColumns
FROM tracks WHERE album_title_key IS NOT NULL AND
  (album_artist_key, album_title_key) IN (
    SELECT t.album_artist_key, t.album_title_key
    FROM track_artists AS ta JOIN tracks AS t ON t.id = ta.track_id
    WHERE ta.artist_key = ?1 AND t.album_title_key IS NOT NULL)
$_albumGroup''';

/// One row per artist key, from `track_artists`: the shown spelling (the
/// smallest), the tracks crediting it and the distinct albums they are on.
/// Names only found as album artist are not artists here.
const artistCreditsSql = '''
SELECT ta.artist_key AS artist_key, min(ta.artist_name) AS name,
  count(*) AS n,
  count(DISTINCT t.album_artist_key || char(31) || t.album_title_key) AS albums
FROM track_artists AS ta JOIN tracks AS t ON t.id = ta.track_id
GROUP BY ta.artist_key''';

/// Disc then track, unknown numbers last; shared by the album and artist
/// pages so both list an album the same way.
const discTrackOrderSql =
    't.disc_no IS NULL, t.disc_no, t.track_no IS NULL, t.track_no, '
    't.title_sort, t.id';

/// The columns of a [BrowseTrack], from `tracks AS t`.
const _browseTrackColumns = '''
t.id, t.path, t.title, t.artist, t.album, t.album_artist, t.year, t.disc_no,
t.track_no, t.duration_ms, t.cover_key,
t.album_artist_key AS ak, t.album_title_key AS tk''';

/// `?1`, `?2`: the parts of an [AlbumKey].
const albumTracksSql =
    '''
SELECT $_browseTrackColumns FROM tracks AS t
WHERE t.album_artist_key = ?1 AND t.album_title_key = ?2
ORDER BY $discTrackOrderSql''';

/// `?1`: an artist key. Matches the names credited in `artist` only (not
/// `album_artist`). Albums stay together, by album key then disc and track;
/// the artist page puts the albums in the order of its tiles.
const artistTracksSql =
    '''
SELECT $_browseTrackColumns
FROM track_artists AS ta JOIN tracks AS t ON t.id = ta.track_id
WHERE ta.artist_key = ?1
ORDER BY t.album_artist_key, t.album_title_key, $discTrackOrderSql''';

/// The columns of a [TrackListItem].
const songColumns = 'id, path, title, artist, album, duration_ms, cover_key';

/// ORDER BY of the Songs list. Unknown values go last in both directions;
/// [descending] flips only the main key; ties fall back to title then id.
String songsOrderSql(SongOrder order, {bool descending = false}) {
  final dir = descending ? 'DESC' : 'ASC';
  const tail = 'title_sort, id';
  return switch (order) {
    SongOrder.title => 'title_sort $dir, id',
    SongOrder.artist => 'artist_sort IS NULL, artist_sort $dir, $tail',
    SongOrder.album => 'album_sort IS NULL, album_sort $dir, $tail',
    SongOrder.year => 'year IS NULL, year $dir, $tail',
    SongOrder.dateAdded => 'added_at $dir, $tail',
    SongOrder.duration => 'duration_ms IS NULL, duration_ms $dir, $tail',
  };
}

/// Queries for browsing the library by album and artist, and the sortable
/// Songs list. They run once per call; a screen that follows `tracks` wraps
/// them in `throttledTracksQuery`.
extension LibraryBrowseQueries on LibraryDatabase {
  /// Every album with a title, in no particular order.
  Future<List<AlbumSummary>> albums() =>
      _query(albumsSql, const [], _albumSummary).get();

  /// One album by key; null when it has no tracks.
  Future<AlbumSummary?> album(AlbumKey key) => _query(albumSql, [
    Variable(key.artistKey),
    Variable(key.titleKey),
  ], _albumSummary).getSingleOrNull();

  /// The albums with a track crediting [artistKey], in no particular order.
  Future<List<AlbumSummary>> artistAlbums(String artistKey) =>
      _query(artistAlbumsSql, [Variable(artistKey)], _albumSummary).get();

  /// One row per artist key (see `artistKey` in `artist_names.dart`).
  Future<List<ArtistCredit>> artistCredits() =>
      _query(artistCreditsSql, const [], (row) {
        return ArtistCredit(
          key: row.read<String>('artist_key'),
          name: row.read<String>('name'),
          trackCount: row.read<int>('n'),
          albumCount: row.read<int>('albums'),
        );
      }).get();

  /// The tracks of one album, by disc then track.
  Future<List<BrowseTrack>> albumTracks(AlbumKey key) => _query(
    albumTracksSql,
    [Variable(key.artistKey), Variable(key.titleKey)],
    _browseTrack,
  ).get();

  /// The tracks crediting [artistKey], by album key, disc and track.
  Future<List<BrowseTrack>> artistTracks(String artistKey) =>
      _query(artistTracksSql, [Variable(artistKey)], _browseTrack).get();

  Selectable<T> _query<T>(
    String sql,
    List<Variable> variables,
    T Function(QueryRow row) map,
  ) => customSelect(sql, variables: variables, readsFrom: {tracks}).map(map);
}

/// Reads a row of [songColumns].
TrackListItem trackListItemFromRow(QueryRow row) => TrackListItem(
  id: row.read<int>('id'),
  path: row.read<String>('path'),
  title: row.read<String>('title'),
  artist: row.readNullable<String>('artist'),
  album: row.readNullable<String>('album'),
  durationMs: row.readNullable<int>('duration_ms'),
  coverKey: row.readNullable<String>('cover_key'),
);

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
    coverKey: row.readNullable<String>('cover_key'),
  );
}

AlbumSummary _albumSummary(QueryRow row) => AlbumSummary(
  key: AlbumKey(row.read<String>('ak'), row.read<String>('tk')),
  title: row.read<String>('title'),
  artist: row.readNullable<String>('artist'),
  year: row.readNullable<int>('year'),
  trackCount: row.read<int>('n'),
  durationMs: row.readNullable<int>('duration'),
  addedAt: row.read<int>('added'),
  coverKey: row.readNullable<String>('cover'),
  titleSort: row.readNullable<String>('title_sort'),
);
