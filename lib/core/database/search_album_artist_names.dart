
import 'library_database.dart';

/// Every distinct album display artist of the albums not told apart by
/// artist (empty artist key), the only albums that can merge several artists.
/// An album shows one name (`AlbumSummary.artist`); this is the full set.
const _mergedAlbumArtistsSql = '''
SELECT album_title_key AS tk, album_display_artist AS name
FROM tracks
WHERE album_artist_key = '' AND album_title_key IS NOT NULL
  AND album_display_artist IS NOT NULL
GROUP BY album_title_key, album_display_artist''';

extension SearchAlbumArtistNames on LibraryDatabase {
  /// The artist names of each album that has more than one, sorted, so a
  /// search can match a merged album by any of them. Albums with a single
  /// name are left out: `AlbumSummary.artist` already has it. Read-only; one
  /// pass over every artistless-key album, so callers run it only when some
  /// album merged several artists and keep it throttled.
  Future<Map<AlbumKey, List<String>>> mergedAlbumArtistNames() async {
    final rows = await customSelect(
      _mergedAlbumArtistsSql,
      readsFrom: {tracks},
    ).get();
    final byTitle = <String, List<String>>{};
    for (final row in rows) {
      (byTitle[row.read<String>('tk')] ??= []).add(row.read<String>('name'));
    }
    return {
      for (final e in byTitle.entries)
        if (e.value.length > 1) AlbumKey('', e.key): e.value..sort(),
    };
  }
}
