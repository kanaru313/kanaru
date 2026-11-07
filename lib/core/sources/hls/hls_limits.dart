// Bounds that keep one untrusted playlist from using unbounded memory or
// time. Going over a count, line or URI bound is `tooLarge`; a bad duration
// or byte range is `invalid`.

/// Playlist body bytes. The parser takes bytes already read; the loader reads
/// at most this many and refuses a longer body itself.
const hlsMaxPlaylistBytes = 4 * 1024 * 1024;

const hlsMaxSegments = 20000;
const hlsMaxVariants = 200;
const hlsMaxRenditions = 200;

/// One line, in bytes, line ending excluded.
const hlsMaxLineBytes = 16 * 1024;

/// One URI, counted in UTF-16 code units of its text (the line bound already
/// caps the bytes).
const hlsMaxUriLength = 8 * 1024;

/// One `EXTINF` duration.
const hlsMaxSegmentDuration = Duration(seconds: 3600);

/// The sum of all `EXTINF` durations.
const hlsMaxTotalDuration = Duration(hours: 24);

/// Largest end (offset + length) of a byte range. Chained implicit offsets
/// can add up past what any real file holds.
const hlsMaxByteRangeEnd = 9007199254740992; // 2^53
