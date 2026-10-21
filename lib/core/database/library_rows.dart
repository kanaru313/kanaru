/// Version of the rules that pick a track's cover: source order, accepted
/// formats and thumbnail size. Tracks scanned under a lower version are read
/// again on the next scan even when the file is unchanged. Bump it when those
/// rules change; when the thumbnail size changes, also rename the size folder
/// of the cover cache (`covers/<size>`) so old and new thumbnails never mix.
const coverScanVersion = 1;

/// Version of the Rust tag reader's idea of unreadable files. Bump it (and
/// `PERMANENT_ERROR_PREFIX` in `rust/src/tag_reader.rs`) when the reader
/// learns to read more files, so files marked unreadable by an older reader
/// are tried again.
const tagReaderVersion = 1;

/// Start of a `scanError` that reading again cannot fix with this reader
/// version (corrupt or unsupported content). Other errors (I/O, permissions)
/// and marks of older versions may pass and are retried on every scan.
const permanentScanErrorPrefix = 'permanent:v$tagReaderVersion:';

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

  /// The last read of its tags failed with an error that may pass (not a
  /// [permanentScanErrorPrefix] one); a rescan tries again even when the file
  /// is unchanged.
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
