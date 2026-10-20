/// Version of the rules that pick a track's cover: source order, accepted
/// formats and thumbnail size. Tracks scanned under a lower version are read
/// again on the next scan even when the file is unchanged. Bump it when those
/// rules change; when the thumbnail size changes, also rename the size folder
/// of the cover cache (`covers/<size>`) so old and new thumbnails never mix.
const coverScanVersion = 1;

/// What a rescan needs to know about a track already in the database.
class TrackSnapshot {
  const TrackSnapshot({
    required this.id,
    required this.path,
    required this.mtimeMs,
    required this.sizeBytes,
    this.hasScanError = false,
    this.coverScanVersion = 0,
  });

  final int id;
  final String path;
  final int mtimeMs;
  final int sizeBytes;

  /// The last read of its tags failed; a rescan tries again even when the
  /// file is unchanged.
  final bool hasScanError;

  /// The cover rules its cover was last looked for with; see the top-level
  /// `coverScanVersion`.
  final int coverScanVersion;
}

/// The few columns a track list row shows, so listing a big library does not
/// load every tag.
class TrackListItem {
  const TrackListItem({
    required this.id,
    required this.path,
    required this.title,
    this.artist,
    this.album,
    this.durationMs,
    this.coverKey,
  });

  final int id;
  final String path;
  final String title;
  final String? artist;
  final String? album;
  final int? durationMs;

  /// Cover thumbnail key in the cover cache; null when there is no cover.
  final String? coverKey;
}
