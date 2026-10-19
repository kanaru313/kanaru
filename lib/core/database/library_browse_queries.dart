import 'package:drift/drift.dart';

import 'library_database.dart';

/// The first artist of the `artist` column: the part before the first
/// `"; "`, or the whole value.
const firstArtistSql =
    "CASE WHEN instr(artist, '; ') > 0 "
    "THEN substr(artist, 1, instr(artist, '; ') - 1) ELSE artist END";

/// Album key, artist part. Computed only in SQL: SQLite's `lower()` folds
/// ASCII only, so a key made in Dart would not match. Cut to 256 characters
/// so route keys stay bounded even for huge tags.
const albumArtistKeySql =
    "lower(substr(coalesce(album_artist, $firstArtistSql, ''), 1, 256))";

/// Album key, title part.
const albumTitleKeySql = 'lower(substr(album, 1, 256))';

/// Disc then track, unknown numbers last; shared by the album and artist
/// pages so both list an album the same way.
const discTrackOrderSql =
    'disc_no IS NULL, disc_no, track_no IS NULL, track_no, '
    'title COLLATE NOCASE, id';

const albumsSql =
    '''
SELECT $albumArtistKeySql AS ak, $albumTitleKeySql AS tk,
  min(album) AS title, min(coalesce(album_artist, $firstArtistSql)) AS artist,
  max(year) AS year, count(*) AS n, sum(duration_ms) AS duration,
  max(added_at) AS added
FROM tracks WHERE album IS NOT NULL
GROUP BY ak, tk''';

/// Per exact `artist` value: its album keys joined by char(30), each key's
/// two parts joined by char(31). The inner query removes duplicate keys.
const artistCreditsSql =
    '''
SELECT artist, lower(artist) AS artist_key, sum(n) AS n,
  group_concat(album_key, char(30)) AS album_keys
FROM (
  SELECT artist, count(*) AS n,
    CASE WHEN album IS NOT NULL
      THEN $albumArtistKeySql || char(31) || $albumTitleKeySql END AS album_key
  FROM tracks WHERE artist IS NOT NULL
  GROUP BY artist, album_key
)
GROUP BY artist''';

const _browseTrackColumns =
    '''
id, path, title, artist, album, album_artist, year, disc_no, track_no,
duration_ms, lower(artist) AS artist_keys,
CASE WHEN album IS NOT NULL THEN $albumArtistKeySql END AS ak,
CASE WHEN album IS NOT NULL THEN $albumTitleKeySql END AS tk''';

/// `?1`, `?2`: the parts of an [AlbumKey].
const albumTracksSql =
    '''
SELECT $_browseTrackColumns FROM tracks
WHERE album IS NOT NULL AND $albumArtistKeySql = ?1 AND $albumTitleKeySql = ?2
ORDER BY $discTrackOrderSql''';

/// `?1`: an artist key. Matches whole names in `artist` only (not
/// `album_artist`); `instr` instead of `LIKE` so `%` and `_` are literal.
const artistTracksSql =
    '''
SELECT $_browseTrackColumns FROM tracks
WHERE instr('; ' || lower(artist) || '; ', '; ' || ?1 || '; ') > 0
ORDER BY year IS NULL, year, album IS NULL, lower(album), $discTrackOrderSql''';

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
          artistKey: row.read<String>('artist_key'),
          trackCount: row.read<int>('n'),
          albumKeys: {
            if (keys != null)
              for (final key in keys.split('\u001e')) _parseAlbumKey(key),
          },
        );
      });

  /// The tracks of one album, by disc then track.
  Stream<List<BrowseTrack>> watchAlbumTracks(AlbumKey key) => _watch(
    albumTracksSql,
    [Variable(key.artistKey), Variable(key.titleKey)],
    _browseTrack,
  );

  /// The tracks crediting [artistKey] (a lower-cased name from
  /// [watchArtistCredits]), by year, album, disc and track.
  Stream<List<BrowseTrack>> watchArtistTracks(String artistKey) =>
      _watch(artistTracksSql, [Variable(artistKey)], _browseTrack);

  /// All tracks for the Songs list. The default order is the same as
  /// [LibraryDatabase.watchTrackListItems].
  Stream<List<TrackListItem>> watchSongs({
    SongOrder order = SongOrder.title,
    bool descending = false,
  }) => _watch(
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

  Stream<List<T>> _watch<T>(
    String sql,
    List<Variable> variables,
    T Function(QueryRow row) map,
  ) => _query(sql, variables, map).watch();

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
    artistKeys: row.readNullable<String>('artist_keys'),
  );
}
