import 'dart:convert';

import 'package:drift/drift.dart';

import 'library_browse_queries.dart';
import 'library_database.dart';

// The stored language strings travel as one JSON array parameter read with
// `json_each`, so a library with many distinct spellings never hits SQLite's
// variable limit.

/// `?1`: a JSON array of the stored language strings. The albums holding at
/// least one track of them, each aggregated over all its tracks (not only
/// those of the language).
const languageAlbumsSql =
    '''
SELECT $albumColumns
FROM tracks WHERE album_title_key IS NOT NULL AND
  (album_artist_key, album_title_key) IN (
    SELECT album_artist_key, album_title_key FROM tracks
    WHERE language IN (SELECT value FROM json_each(?1))
      AND album_title_key IS NOT NULL)
$albumGroupSql''';

/// `?1`: a JSON array of the stored language strings.
const languageTracksSql =
    '''
SELECT $browseTrackColumns FROM tracks AS t
WHERE t.language IN (SELECT value FROM json_each(?1))
ORDER BY t.title_sort, t.id''';

/// Queries for browsing the library by language. A language is a set of
/// stored `language` strings (see `splitLanguages` in `language_tags.dart`),
/// so the page queries take those raw strings. They run once per call; a
/// screen that follows `tracks` wraps them in `throttledTracksQuery`.
extension LanguageQueries on LibraryDatabase {
  /// Every stored language string with the tracks holding it. Tracks with no
  /// language tag are left out.
  Future<List<({String raw, int count})>> languageCounts() =>
      customSelect(
            'SELECT language, count(*) AS n FROM tracks '
            'WHERE language IS NOT NULL GROUP BY language',
            readsFrom: {tracks},
          )
          .map(
            (row) =>
                (raw: row.read<String>('language'), count: row.read<int>('n')),
          )
          .get();

  /// The tracks whose language string is one of [raws], by title.
  Future<List<BrowseTrack>> languageTracks(List<String> raws) => raws.isEmpty
      ? Future.value(const [])
      : customSelect(
          languageTracksSql,
          variables: [Variable(jsonEncode(raws))],
          readsFrom: {tracks},
        ).map(browseTrackFromRow).get();

  /// The albums with a track whose language string is one of [raws], in no
  /// particular order.
  Future<List<AlbumSummary>> languageAlbums(List<String> raws) => raws.isEmpty
      ? Future.value(const [])
      : customSelect(
          languageAlbumsSql,
          variables: [Variable(jsonEncode(raws))],
          readsFrom: {tracks},
        ).map(albumSummaryFromRow).get();
}
