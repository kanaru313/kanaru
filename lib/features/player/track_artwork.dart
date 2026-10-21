import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/playing_track_art.dart';
import '../../core/player/playing_track_original_cover.dart';
import 'original_cover_layer.dart';

/// Cover art of a track at [size] with rounded corners, or a music note when
/// the track has none, the file is missing or it is not a local file (remote
/// covers are not loaded here).
class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    super.key,
    required this.artUri,
    required this.size,
    this.radius = 8,
    this.layered = false,
    this.original,
  }) : assert(layered || original == null, 'an original needs layered');

  /// Plain path or `file://` URI, as in `Track.artUri`.
  final String? artUri;
  final double size;
  final double radius;

  /// Whether the cover is built as a stack, so the thumbnail keeps its place
  /// whether or not an [original] is over it. A view that shows [original]
  /// sets this for good: a stack that appears with the original and goes
  /// with it would rebuild the thumbnail image, and blank it, at every
  /// track change.
  final bool layered;

  /// The full-size cover, drawn over the thumbnail once it decodes. Needs
  /// [layered].
  final OriginalCover? original;

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
    // Decode no larger than shown (rounded up to a step): a big cover would
    // otherwise sit in the image cache at full size.
    final decodeWidth = _decodeWidth(
      size * MediaQuery.devicePixelRatioOf(context),
    );
    final thumbnail = file == null
        ? placeholder
        : Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: decodeWidth,
            // No blank frame between one track's cover and the next.
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => placeholder,
          );
    final original = this.original;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: layered
            ? Stack(
                fit: StackFit.expand,
                children: [
                  thumbnail,
                  if (original != null)
                    // Keyed by track: the next track starts a fresh layer
                    // instead of holding this one's last frame.
                    OriginalCoverLayer(
                      key: ValueKey(original.uri),
                      bytes: original.bytes,
                      decodeWidth: decodeWidth,
                    ),
                ],
              )
            : thumbnail,
      ),
    );
  }
}

/// Cover of the playing track as core resolves it (its library cover, else
/// the art it was queued with), at [size] with [radius]. Only this widget
/// rebuilds when the cover changes.
class PlayingTrackArtwork extends ConsumerWidget {
  const PlayingTrackArtwork({super.key, required this.size, this.radius = 8});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TrackArtwork(
    artUri: ref.watch(playingTrackArtProvider),
    size: size,
    radius: radius,
  );
}
