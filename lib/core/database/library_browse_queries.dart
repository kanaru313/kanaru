import 'package:drift/drift.dart';

import 'artist_names.dart';
import 'library_database.dart';

// Every query reads the keys stored by `trackKeysFor` (track_keys.dart) and
// the `track_artists` rows, so grouping and ordering are index work in SQLite
// and no Dart code runs per track.

/// The columns of an [AlbumSummary]: the shown title, artist and year are
/// aggregates over the stored columns, so the list, the album page and the
/// artist page agree whichever track order the database returns.
///
/// `artist_lo` and `artist_hi` are the smallest and largest album display
/// artist (the album artist, else the first track artist), compared ignoring
/// ASCII case. [albumSummaryFromRow] flags an album merged from several
/// artists when its key has no artist (albums not told apart by artist) and
/// the two differ by `artistKey`, which also folds non-ASCII case. Min and
/// max keep the group-by-index plan (checked by the query plan tests).
const albumColumns = '''
album_artist_key AS ak, album_title_key AS tk, min(album) AS title,
  min(album_display_artist) AS artist, max(year) AS year, count(*) AS n,
  nullif(sum(duration_ms), 0) AS duration, max(added_at) AS added,
  min(cover_key) AS cover, min(album_sort) AS title_sort,
  min(album_display_artist COLLATE NOCASE) AS artist_lo,
  max(album_display_artist COLLATE NOCASE) AS artist_hi''';

const albumGroupSql = 'GROUP BY album_artist_key, album_title_key';

/// Albums: one row per (album artist key, album title key).
const albumsSql =
    '''
SELECT $albumColumns
FROM tracks WHERE album_title_key IS NOT NULL
$albumGroupSql''';

/// `?1`, `?2`: the parts of an [AlbumKey]. At most one row.
const albumSql =
    '''
SELECT $albumColumns
FROM tracks WHERE album_artist_key = ?1 AND album_title_key = ?2
$albumGroupSql''';

/// `?1`: an artist key. The albums holding at least one of their tracks,
/// each aggregated over all its tracks (not only the artist's).
const artistAlbumsSql =
    '''
SELECT $albumColumns
FROM tracks WHERE album_title_key IS NOT NULL AND
  (album_artist_key, album_title_key) IN (
    SELECT t.album_artist_key, t.album_title_key
    FROM track_artists AS ta JOIN tracks AS t ON t.id = ta.track_id
    WHERE ta.artist_key = ?1 AND t.album_title_key IS NOT NULL)
$albumGroupSql''';

/// One row per artist key, from `track_artists`: the shown spelling (the
/// smallest), the tracks crediting it, the distinct albums they are on, the
/// first and last year (0 counts as unknown) and the total length. Names
/// only found as album artist are not artists here.
const artistCreditsSql = '''
SELECT ta.artist_key AS artist_key, min(ta.artist_name) AS name,
  count(*) AS n,
  count(DISTINCT t.album_artist_key || char(31) || t.album_title_key) AS albums,
  min(nullif(t.year, 0)) AS year_lo, max(nullif(t.year, 0)) AS year_hi,
  nullif(sum(t.duration_ms), 0) AS ms
FROM track_artists AS ta JOIN tracks AS t ON t.id = ta.track_id
GROUP BY ta.artist_key''';

/// Disc then track, unknown numbers last; shared by the album and artist
/// pages so both list an album the same way.
const discTrackOrderSql =
    't.disc_no IS NULL, t.disc_no, t.track_no IS NULL, t.track_no, '
    't.title_sort, t.id';

/// The columns of a [BrowseTrack], from `tracks AS t`.
const browseTrackColumns = '''
t.id, t.path, t.title, t.artist, t.album, t.album_artist, t.year, t.disc_no,
t.track_no, t.duration_ms, t.cover_key,
t.album_artist_key AS ak, t.album_title_key AS tk''';

/// `?1`, `?2`: the parts of an [AlbumKey].
const albumTracksSql =
    '''
SELECT $browseTrackColumns FROM tracks AS t
WHERE t.album_artist_key = ?1 AND t.album_title_key = ?2
ORDER BY $discTrackOrderSql''';

/// `?1`: an artist key. Matches the names credited in `artist` only (not
/// `album_artist`). Albums stay together, by album key then disc and track;
/// the artist page puts the albums in the order of its tiles.
const artistTracksSql =
    '''
SELECT $browseTrackColumns
FROM track_artists AS ta JOIN tracks AS t ON t.id = ta.track_id
WHERE ta.artist_key = ?1
ORDER BY t.album_artist_key, t.album_title_key, $discTrackOrderSql''';

/// The columns of a [TrackListItem].
const songColumns =
    'id, path, title, artist, album, year, duration_ms, cover_key';

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
      _query(albumsSql, const [], albumSummaryFromRow).get();

  /// One album by key; null when it has no tracks.
  Future<AlbumSummary?> album(AlbumKey key) => _query(albumSql, [
    Variable(key.artistKey),
    Variable(key.titleKey),
  ], albumSummaryFromRow).getSingleOrNull();

  /// The albums with a track crediting [artistKey], in no particular order.
  Future<List<AlbumSummary>> artistAlbums(String artistKey) =>
      _query(artistAlbumsSql, [Variable(artistKey)], albumSummaryFromRow).get();

  /// One row per artist key (see `artistKey` in `artist_names.dart`).
  Future<List<ArtistCredit>> artistCredits() =>
      _query(artistCreditsSql, const [], (row) {
        return ArtistCredit(
          key: row.read<String>('artist_key'),
          name: row.read<String>('name'),
          trackCount: row.read<int>('n'),
          albumCount: row.read<int>('albums'),
          firstYear: row.readNullable<int>('year_lo'),
          lastYear: row.readNullable<int>('year_hi'),
          durationMs: row.readNullable<int>('ms'),
        );
      }).get();

  /// The tracks of one album, by disc then track.
  Future<List<BrowseTrack>> albumTracks(AlbumKey key) => _query(
    albumTracksSql,
    [Variable(key.artistKey), Variable(key.titleKey)],
    browseTrackFromRow,
  ).get();

  /// The tracks crediting [artistKey], by album key, disc and track.
  Future<List<BrowseTrack>> artistTracks(String artistKey) =>
      _query(artistTracksSql, [Variable(artistKey)], browseTrackFromRow).get();

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
  year: row.readNullable<int>('year'),
  durationMs: row.readNullable<int>('duration_ms'),
  coverKey: row.readNullable<String>('cover_key'),
);

/// Reads a row of [browseTrackColumns].
BrowseTrack browseTrackFromRow(QueryRow row) {
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

/// Reads a row of [albumColumns].
AlbumSummary albumSummaryFromRow(QueryRow row) {
  final artist = row.readNullable<String>('artist');
  final albumArtistKey = row.read<String>('ak');
  final lo = row.readNullable<String>('artist_lo');
  final hi = row.readNullable<String>('artist_hi');
  return AlbumSummary(
    key: AlbumKey(albumArtistKey, row.read<String>('tk')),
    title: row.read<String>('title'),
    artist: artist,
    year: row.readNullable<int>('year'),
    trackCount: row.read<int>('n'),
    durationMs: row.readNullable<int>('duration'),
    addedAt: row.read<int>('added'),
    coverKey: row.readNullable<String>('cover'),
    titleSort: row.readNullable<String>('title_sort'),
    variousArtists:
        albumArtistKey.isEmpty &&
        lo != null &&
        hi != null &&
        artistKey(lo) != artistKey(hi),
  );
}
