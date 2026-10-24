import 'dart:io';

import 'package:material_ui/material_ui.dart';

/// Largest decode width: the cover thumbnails are at most this wide, so
/// decoding them larger only wastes memory.
const coverDecodeMaxWidth = 512;

/// The width to decode a cover shown [physicalPixels] wide: rounded up to
/// 64, 128, 256 or 512, never more. Fixed steps keep the image cache key
/// stable while a window is resized, and let tiles of similar size share
/// one decoded bitmap.
int coverDecodeWidth(double physicalPixels) {
  for (final step in const [64, 128, 256]) {
    if (physicalPixels <= step) return step;
  }
  return coverDecodeMaxWidth;
}

/// Corner radius of a cover [size] px wide: 4 below 64 px, 8 from there up.
double coverArtRadius(double size) => size < 64 ? 4 : 8;

/// A square cover picture from the file at [path], or [placeholder] when
/// there is no path or the file cannot be shown (missing, empty, corrupt).
/// Corners are rounded by [radius], else by [coverArtRadius].
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.path,
    required this.size,
    required this.placeholder,
    this.radius,
  });

  final String? path;
  final double size;
  final Widget placeholder;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final file = path;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? coverArtRadius(size)),
      child: SizedBox.square(
        dimension: size,
        child: file == null
            ? placeholder
            : Image.file(
                File(file),
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: coverDecodeWidth(size * dpr),
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
