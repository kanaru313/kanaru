import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;

import '../paths/app_directories.dart';

/// Revision of the color code in `rust/src/cover_colors.rs`
/// (`COLOR_ALGO_REVISION`); change both together.
const coverColorAlgoRevision = 1;

/// What `cover_colors.algo_version` must hold for a row to count: the color
/// code's revision and the thumbnail size it read, so a new algorithm or a
/// new thumbnail size makes every stored row count as missing.
const coverColorAlgoVersion =
    coverColorAlgoRevision * 100000 + coverThumbnailSize;

/// How long the Now Playing background takes to fade to the colors of a new
/// cover; zero when the system asks for reduced motion. The app theme itself
/// changes at once.
const coverThemeTransition = Duration(milliseconds: 300);

/// How many colors a stored palette may hold.
const maxPaletteColors = 8;

final _palettePattern = RegExp(r'^[0-9a-f]{8}(,[0-9a-f]{8}){0,7}$');

/// The colors of one cover, ready for the theme and the Now Playing
/// background.
@immutable
class CoverPalette {
  const CoverPalette({required this.seed, required this.colors});

  /// Seed for the app's color scheme; `null` when the cover is gray (no
  /// accent color fits), so the app keeps the system accent.
  final Color? seed;

  /// Opaque colors of the cover, the most common first; never empty.
  final List<Color> colors;

  @override
  bool operator ==(Object other) =>
      other is CoverPalette &&
      other.seed == seed &&
      listEquals(other.colors, colors);

  @override
  int get hashCode => Object.hash(seed, Object.hashAll(colors));

  @override
  String toString() => 'CoverPalette(seed: $seed, colors: $colors)';
}

/// `cover_colors.palette` for [argb]: lowercase 8-digit ARGB hex joined by
/// commas, in the given order.
String encodePalette(List<int> argb) => [
  for (final color in argb)
    (color & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0'),
].join(',');

/// The colors stored in [text], or `null` when it is not exactly the stored
/// format (one to [maxPaletteColors] lowercase 8-digit hex values).
List<Color>? decodePalette(String text) {
  if (!_palettePattern.hasMatch(text)) return null;
  return [for (final hex in text.split(',')) Color(int.parse(hex, radix: 16))];
}

/// The palette of one stored row, or `null` when the row is damaged: a
/// palette not in the stored format, or a seed that is neither `0` nor
/// opaque.
CoverPalette? paletteFromRow({required int seed, required String palette}) {
  final colors = decodePalette(palette);
  if (colors == null) return null;
  if (seed == 0) return CoverPalette(seed: null, colors: colors);
  if (seed < 0 || seed > 0xFFFFFFFF || seed >> 24 != 0xFF) return null;
  return CoverPalette(seed: Color(seed), colors: colors);
}
