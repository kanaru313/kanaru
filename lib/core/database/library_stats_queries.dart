import 'package:drift/drift.dart';

import 'library_database.dart';

/// How much the library holds, as the Albums and Artists lists would count
/// it. Genres are not here: how many there are depends on the separators the
/// user chose, so the screen counts them from [genreCounts].
typedef LibraryCounts = ({int tracks, int albums, int artists});

/// One row. Albums and artists are counted the way `albumsSql` and
/// `artistCreditsSql` group them, so the numbers match those lists.
const libraryStatsSql = '''
SELECT
  (SELECT count(*) FROM tracks) AS tracks,
  (SELECT count(*) FROM (
     SELECT 1 FROM tracks WHERE album_title_key IS NOT NULL
     GROUP BY album_artist_key, album_title_key)) AS albums,
  (SELECT count(DISTINCT artist_key) FROM track_artists) AS artists''';

extension LibraryStatsQueries on LibraryDatabase {
  /// The counts of the whole library; a screen that follows `tracks` wraps
  /// this in `throttledTracksQuery`. `track_artists` is always written in
  /// the transaction that writes `tracks`, so watching `tracks` is enough.
  Future<LibraryCounts> libraryStats() => customSelect(
    libraryStatsSql,
    readsFrom: {tracks, trackArtists},
  ).map(_fromRow).getSingle();
}

LibraryCounts _fromRow(QueryRow row) => (
  tracks: row.read<int>('tracks'),
  albums: row.read<int>('albums'),
  artists: row.read<int>('artists'),
);
