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
                // Decode no larger than shown: a big cover would otherwise
                // sit in the image cache at full size.
                // At least 1: the image asserts a positive size.
                cacheWidth: max(
                  1,
                  (size * MediaQuery.devicePixelRatioOf(context)).round(),
                ),
                // No blank frame between one track's cover and the next.
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
