import 'package:drift/drift.dart';

import 'library_database.dart';
import 'playlist_page_queries.dart';
import 'playlist_rows.dart';
import 'search_terms.dart';

/// Most entries one playlist filter returns.
const playlistFilterLimit = 1000;

/// The entries of a playlist that match a filter, in playlist order.
class PlaylistMatches {
  const PlaylistMatches(this.entries, {this.truncated = false});

  static const empty = PlaylistMatches([]);

  final List<PlaylistPositionedEntry> entries;

  /// Whether more entries matched than [entries] holds.
  final bool truncated;
}

/// Full-text filter of a playlist, for its in-page filter box.
extension SearchPlaylistQueries on LibraryDatabase {
  /// The entries of playlist [id] whose song has every term of [terms] (see
  /// `searchTerms`) as a word prefix of its title, artist or album, by
  /// position, at most [limit]. An entry whose file is not in the library has
  /// no song to match and never comes back; a song listed twice comes back
  /// once per entry. No terms, no entries.
  Future<PlaylistMatches> playlistEntriesMatching(
    int id,
    List<String> terms, {
    int limit = playlistFilterLimit,
  }) async {
    assert(limit > 0, 'limit must be positive');
    if (terms.isEmpty) return PlaylistMatches.empty;
    final rows = await customSelect(
      '''
SELECT e.id AS entry_id, e.position, e.path, t.id AS track_id, t.title,
  t.artist, t.album, t.year, t.duration_ms, t.cover_key
FROM playlist_entries e
JOIN tracks t ON t.path = e.path
WHERE e.playlist_id = ?1
  AND t.id IN (SELECT rowid FROM track_search WHERE track_search MATCH ?2)
ORDER BY e.position, e.id
LIMIT ?3''',
      variables: [
        Variable.withInt(id),
        Variable.withString(
          '{title_sort artist_search album_search} : (${ftsPrefixQuery(terms)})',
        ),
        // One more than asked for tells whether the list was cut.
        Variable.withInt(limit + 1),
      ],
      readsFrom: {playlistEntries, tracks, trackSearch},
    ).get();
    return PlaylistMatches([
      for (final row in rows.take(limit))
        PlaylistPositionedEntry(
          row.read<int>('position'),
          playlistEntryFromRow(row),
        ),
    ], truncated: rows.length > limit);
  }
}
