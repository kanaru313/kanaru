/// What a rescan needs to know about a track already in the database.
class TrackSnapshot {
  const TrackSnapshot({
    required this.id,
    required this.path,
    required this.mtimeMs,
    required this.sizeBytes,
    this.hasScanError = false,
  });

  final int id;
  final String path;
  final int mtimeMs;
  final int sizeBytes;

  /// The last read of its tags failed; a rescan tries again even when the
  /// file is unchanged.
  final bool hasScanError;
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
  });

  final int id;
  final String path;
  final String title;
  final String? artist;
  final String? album;
  final int? durationMs;
}
