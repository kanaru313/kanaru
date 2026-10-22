import 'package:drift/drift.dart';

import 'library_database.dart';

/// How much the library holds, as the Albums, Artists and Genres lists would
/// count it.
typedef LibraryStats = ({int tracks, int albums, int artists, int genres});

/// One row. Albums and artists are counted the way `albumsSql` and
/// `artistCreditsSql` group them, so the numbers match those lists.
///
/// Genres are the distinct non-empty `genre_search` keys: the tag with case,
/// accents and surrounding spaces folded away, as in search, so "Rock" and
/// "rock " are one genre. A multi-value tag ("Rock; Pop") counts as one
/// genre; splitting it needs a separator rule that does not exist yet.
const libraryStatsSql = '''
SELECT
  (SELECT count(*) FROM tracks) AS tracks,
  (SELECT count(*) FROM (
     SELECT 1 FROM tracks WHERE album_title_key IS NOT NULL
     GROUP BY album_artist_key, album_title_key)) AS albums,
  (SELECT count(DISTINCT artist_key) FROM track_artists) AS artists,
  (SELECT count(DISTINCT genre_search) FROM tracks
     WHERE genre_search <> '') AS genres''';

extension LibraryStatsQueries on LibraryDatabase {
  /// The counts of the whole library; a screen that follows `tracks` wraps
  /// this in `throttledTracksQuery`. `track_artists` is always written in
  /// the transaction that writes `tracks`, so watching `tracks` is enough.
  Future<LibraryStats> libraryStats() => customSelect(
    libraryStatsSql,
    readsFrom: {tracks, trackArtists},
  ).map(_fromRow).getSingle();
}

LibraryStats _fromRow(QueryRow row) => (
  tracks: row.read<int>('tracks'),
  albums: row.read<int>('albums'),
  artists: row.read<int>('artists'),
  genres: row.read<int>('genres'),
);
