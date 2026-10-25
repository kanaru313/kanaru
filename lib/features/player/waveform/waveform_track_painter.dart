import 'package:material_ui/material_ui.dart';

import 'waveform_bar_layout.dart';
import 'waveform_pictures.dart';

/// Draws the recorded bars with the thumb at [progress]: played bars left of
/// the thumb, rest bars right of it, a cleared band around it.
///
/// A tick only changes [progress], so painting is two clipped
/// `drawPicture`s and one rounded rectangle: no path or picture is built.
/// The two clips are separate save/restore pairs, so the second never sees
/// the first.
class WaveformTrackPainter extends CustomPainter {
  const WaveformTrackPainter({
    required this.progress,
    required this.pictures,
    required this.thumbColor,
  });

  final double progress;
  final WaveformPicturePair pictures;
  final Color thumbColor;

  @override
  void paint(Canvas canvas, Size size) {
    final thumbX = (progress * size.width).clamp(
      waveformThumbWidth / 2,
      size.width - waveformThumbWidth / 2,
    );
    final playedEnd = thumbX - waveformThumbClearance;
    final restStart = thumbX + waveformThumbClearance;
    if (playedEnd > 0) {
      canvas
        ..save()
        ..clipRect(Rect.fromLTRB(0, 0, playedEnd, size.height))
        ..drawPicture(pictures.played)
        ..restore();
    }
    if (restStart < size.width) {
      canvas
        ..save()
        ..clipRect(Rect.fromLTRB(restStart, 0, size.width, size.height))
        ..drawPicture(pictures.rest)
        ..restore();
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(thumbX, size.height / 2),
          width: waveformThumbWidth,
          height: size.height,
        ),
        const Radius.circular(waveformThumbWidth / 2),
      ),
      Paint()..color = thumbColor,
    );
  }

  @override
  bool shouldRepaint(WaveformTrackPainter old) =>
      old.progress != progress ||
      old.pictures != pictures ||
      old.thumbColor != thumbColor;
}
