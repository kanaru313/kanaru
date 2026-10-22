/// Most covers a playlist collage shows.
const playlistCollageSize = 4;

/// The first [playlistCollageSize] distinct non-null keys of [keys], in
/// order. Distinct, because tracks of one album share a cover and a collage
/// of four identical tiles says less than the single picture; first by
/// position, so the collage matches the top of the list.
List<String> pickCollageKeys(Iterable<String?> keys) {
  final picked = <String>[];
  for (final key in keys) {
    if (key == null || picked.contains(key)) continue;
    picked.add(key);
    if (picked.length == playlistCollageSize) break;
  }
  return picked;
}
