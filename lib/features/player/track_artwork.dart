import 'dart:io';
import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// Cover art of a track at [size] with rounded corners, or a music note when
/// the track has none, the file is missing or it is not a local file (remote
/// covers are not loaded here).
class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    super.key,
    required this.artUri,
    required this.size,
    this.radius = 8,
  });

  /// Plain path or `file://` URI, as in `Track.artUri`.
  final String? artUri;
  final double size;
  final double radius;

  /// Decode widths are multiples of this, so resizing the window does not
  /// decode (and cache) a new image for every pixel of growth.
  static const _decodeStep = 128;

  /// [pixels] rounded up to a multiple of [_decodeStep], at least one step
  /// (the image asserts a positive size).
  static int _decodeWidth(double pixels) =>
      max(1, (pixels / _decodeStep).ceil()) * _decodeStep;

  static File? _fileFor(String? uri) {
    if (uri == null || uri.isEmpty) return null;
    if (uri.startsWith('/')) return File(uri);
    final parsed = Uri.tryParse(uri);
    return parsed != null && parsed.scheme == 'file'
        ? File.fromUri(parsed)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: size / 2,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
    final file = _fileFor(artUri);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: file == null
            ? placeholder
            : Image.file(
                file,
                fit: BoxFit.cover,
                // Decode no larger than shown (rounded up to a step): a big
                // cover would otherwise sit in the image cache at full size.
                cacheWidth: _decodeWidth(
                  size * MediaQuery.devicePixelRatioOf(context),
                ),
                // No blank frame between one track's cover and the next.
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
