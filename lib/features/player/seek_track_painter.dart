import 'package:material_ui/material_ui.dart';

/// Thickness of both track segments.
const _stroke = 4.0;

/// Pill-shaped thumb, standing upright.
const _thumbWidth = 4.0;
const _thumbHeight = 16.0;

/// Room between the thumb and each segment's rounded end.
const _gap = 4.0;

/// Seek track: the played part, a gap, an upright pill thumb at [progress],
/// a gap, then the part still to play.
class SeekTrackPainter extends CustomPainter {
  const SeekTrackPainter({
    required this.progress,
    required this.playedColor,
    required this.restColor,
  });

  final double progress;
  final Color playedColor;
  final Color restColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.height / 2;
    final thumbX = (progress * size.width).clamp(
      _thumbWidth / 2,
      size.width - _thumbWidth / 2,
    );
    // Round caps reach half the stroke past each end.
    final playedEnd = thumbX - _thumbWidth / 2 - _gap - _stroke / 2;
    final restStart = thumbX + _thumbWidth / 2 + _gap + _stroke / 2;
    final line = Paint()
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (playedEnd > _stroke / 2) {
      canvas.drawLine(
        Offset(_stroke / 2, center),
        Offset(playedEnd, center),
        line..color = playedColor,
      );
    }
    if (restStart < size.width - _stroke / 2) {
      canvas.drawLine(
        Offset(restStart, center),
        Offset(size.width - _stroke / 2, center),
        line..color = restColor,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(thumbX, center),
          width: _thumbWidth,
          height: _thumbHeight,
        ),
        const Radius.circular(_thumbWidth / 2),
      ),
      Paint()..color = playedColor,
    );
  }

  @override
  bool shouldRepaint(SeekTrackPainter old) =>
      old.progress != progress ||
      old.playedColor != playedColor ||
      old.restColor != restColor;
}
