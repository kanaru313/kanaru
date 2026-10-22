/// The colors of one cover thumbnail, as worked out by a
/// [CoverColorExtractor].
class CoverColorSample {
  const CoverColorSample({
    required this.key,
    required this.ok,
    this.seed = 0,
    this.palette = const [],
  });

  /// The cover key as given (`<ab>/<hash>.jpg`).
  final String key;

  /// Whether [seed] and [palette] hold the cover's colors. False when the
  /// thumbnail is missing, unreadable or not a JPEG that decodes.
  final bool ok;

  /// Opaque ARGB seed, or `0` when the cover has no color fit to tint the
  /// app (gray).
  final int seed;

  /// Opaque ARGB colors, the most common first.
  final List<int> palette;
}

/// Works out the colors of cover thumbnails in the cover cache.
abstract interface class CoverColorExtractor {
  /// One sample per key in [keys], in the same order; a key that fails gives
  /// `ok: false` and never fails the call. [background] runs the work on
  /// low-priority threads (the scan); otherwise it runs at once (the track
  /// that just started).
  Future<List<CoverColorSample>> extract(
    List<String> keys, {
    required bool background,
  });
}
