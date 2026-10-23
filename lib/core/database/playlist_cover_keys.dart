/// Most covers a playlist collage shows.
const playlistCollageSize = 4;

/// Most non-null keys [pickCollageKeys] looks at. The playlist query reads
/// the same number per playlist, so the grid and the page agree on the
/// collage, and a playlist of thousands of tracks stays cheap.
const playlistCollageScanLimit = 64;

/// Most entries, by position, the collage queries look at. A playlist of tens
/// of thousands of songs with no covers would otherwise be scanned whole to
/// find nothing; covers past this point do not count for the collage.
const playlistCollageEntryScanLimit = 1000;

/// The first [playlistCollageSize] distinct non-null keys among the first
/// [playlistCollageScanLimit] non-null keys of [keys], in order. Distinct,
/// because tracks of one album share a cover and a collage of four
/// identical tiles says less than the single picture; first by position, so
/// the collage matches the top of the list.
List<String> pickCollageKeys(Iterable<String?> keys) {
  final picked = <String>[];
  var scanned = 0;
  for (final key in keys) {
    if (key == null) continue;
    if (++scanned > playlistCollageScanLimit) break;
    if (picked.contains(key)) continue;
    picked.add(key);
    if (picked.length == playlistCollageSize) break;
  }
  return picked;
}
