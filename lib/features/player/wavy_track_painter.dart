import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Thickness of both track segments.
const _stroke = 4.0;

/// Peak height of the wave above or below the track's center line.
const _waveHeight = 3.0;

/// Length of one full wave.
const _wavelength = 24.0;

/// Pill-shaped thumb, standing upright.
const _thumbWidth = 4.0;
const _thumbHeight = 16.0;

/// Room between the thumb and each segment's rounded end.
const _gap = 4.0;

/// Seek track: the played part on the left, a gap, an upright pill thumb at
/// [progress], a gap, then the part still to play. The played part is a
/// sine wave scaled by [amplitude] (0 is a straight line) that travels
/// along the track as [phase] runs from 0 to 1.
class WavyTrackPainter extends CustomPainter {
  WavyTrackPainter({
    required this.progress,
    required this.amplitude,
    required this.phase,
    required this.playedColor,
    required this.restColor,
  }) : super(repaint: Listenable.merge([amplitude, phase]));

  final double progress;
  final Animation<double> amplitude;
  final Animation<double> phase;
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
      _paintPlayed(canvas, line..color = playedColor, center, playedEnd);
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

  void _paintPlayed(Canvas canvas, Paint paint, double center, double end) {
    const start = _stroke / 2;
    final height = _waveHeight * amplitude.value;
    if (height == 0) {
      canvas.drawLine(Offset(start, center), Offset(end, center), paint);
      return;
    }
    // Shifting by the phase moves the crests towards the thumb.
    final shift = 2 * math.pi * phase.value;
    double y(double x) {
      // Flattens over the last half wave so the wave meets the thumb level.
      final taper = ((end - x) / (_wavelength / 2)).clamp(0.0, 1.0);
      return center +
          height * taper * math.sin(2 * math.pi * x / _wavelength - shift);
    }

    final path = Path()..moveTo(start, y(start));
    for (var x = start + 1; x < end; x++) {
      path.lineTo(x, y(x));
    }
    path.lineTo(end, y(end));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavyTrackPainter old) =>
      old.progress != progress ||
      old.amplitude != amplitude ||
      old.phase != phase ||
      old.playedColor != playedColor ||
      old.restColor != restColor;
}
