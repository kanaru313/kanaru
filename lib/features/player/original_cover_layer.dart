import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

/// The full-size cover [bytes], decoded no wider than [decodeWidth], drawn
/// over a thumbnail. Transparent until its first frame, and again if the
/// bytes do not decode, so the thumbnail shows meanwhile. Opaque black behind
/// the picture, as thumbnails are flattened onto black.
///
/// The image cache keys a [MemoryImage] by its bytes and holds them outside
/// its size limit, so the provider is evicted when the bytes or width change
/// and when this layer goes away: a cover seen once is not kept.
class OriginalCoverLayer extends StatefulWidget {
  const OriginalCoverLayer({
    super.key,
    required this.bytes,
    required this.decodeWidth,
  });

  final Uint8List bytes;
  final int decodeWidth;

  @override
  State<OriginalCoverLayer> createState() => _OriginalCoverLayerState();
}

class _OriginalCoverLayerState extends State<OriginalCoverLayer> {
  late ImageProvider _provider = _providerFor(widget);

  /// Whether a frame has been shown. A new provider resets the frame number
  /// the builder sees, but the image keeps its last frame until the next one
  /// decodes (gapless), so only the first decode leaves the layer empty.
  bool _shown = false;

  static ImageProvider _providerFor(OriginalCoverLayer layer) =>
      ResizeImage.resizeIfNeeded(
        layer.decodeWidth,
        null,
        MemoryImage(layer.bytes),
      );

  @override
  void didUpdateWidget(OriginalCoverLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.bytes, oldWidget.bytes) ||
        widget.decodeWidth != oldWidget.decodeWidth) {
      // Evicting an image that is still shown is safe: its stream keeps
      // serving its listeners, it only leaves the cache.
      unawaited(_provider.evict());
      _provider = _providerFor(widget);
    }
  }

  @override
  void dispose() {
    unawaited(_provider.evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Image(
    image: _provider,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
      _shown |= frame != null || wasSynchronouslyLoaded;
      return _shown
          ? ColoredBox(color: Colors.black, child: child)
          : const SizedBox.shrink();
    },
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}
