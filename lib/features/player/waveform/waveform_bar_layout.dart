import 'dart:typed_data';

/// Height of the waveform seek track.
const waveformTrackHeight = 48.0;

/// One bar's width and the empty space between two bars.
const waveformBarWidth = 3.0;
const waveformBarGap = 2.0;
const waveformBarRadius = 1.5;

/// A bar is never shorter or taller than these, centred in the track.
const waveformMinExtent = 2.0;
const waveformMaxExtent = 32.0;

/// The thumb is an upright pill as high as the track.
const waveformThumbWidth = 4.0;

/// Room kept free on each side of the thumb's centre: half the thumb plus the
/// same gap the straight track leaves around it.
const waveformThumbClearance = waveformThumbWidth / 2 + 4.0;

/// Number of bars that fit in [width]: bars start at x = 0, and the last one
/// ends at or before [width].
int waveformBarCount(double width) {
  if (!width.isFinite || width < waveformBarWidth) return 0;
  return ((width + waveformBarGap) / (waveformBarWidth + waveformBarGap))
      .floor();
}

/// Heights of the bars across [width], from [levels] (0 to 255, evenly
/// spaced over [length]).
///
/// Bars map time, not index: bar `j` covers a share of the player's
/// [duration] equal to its share of [width], and takes the mean of the levels
/// whose time falls in it (the level under its start when none does, as when
/// there are fewer levels than bars). A waveform shorter than the duration
/// leaves the bars after it at the minimum; a longer one is cut at the
/// duration. A zero [duration] or [length] gives no bars.
List<double> waveformBarExtents({
  required Uint8List levels,
  required Duration length,
  required Duration duration,
  required double width,
}) {
  final count = waveformBarCount(width);
  final lengthUs = length.inMicroseconds;
  final durationUs = duration.inMicroseconds;
  if (count == 0 || levels.isEmpty || lengthUs <= 0 || durationUs <= 0) {
    return const [];
  }
  final pitch = waveformBarWidth + waveformBarGap;
  final n = levels.length;
  double extentOf(double level) =>
      waveformMinExtent +
      (waveformMaxExtent - waveformMinExtent) * (level / 255);

  return List<double>.generate(count, (j) {
    final startUs = j * pitch / width * durationUs;
    if (startUs >= lengthUs) return waveformMinExtent;
    final endUs = (j + 1) * pitch / width * durationUs;
    // Levels i with startUs <= i / n * length < endUs.
    final first = (startUs / lengthUs * n).ceil();
    final end = (endUs / lengthUs * n).ceil().clamp(0, n);
    if (first >= end) {
      final under = (startUs / lengthUs * n).floor().clamp(0, n - 1);
      return extentOf(levels[under].toDouble());
    }
    var sum = 0;
    for (var i = first; i < end; i++) {
      sum += levels[i];
    }
    return extentOf(sum / (end - first));
  }, growable: false);
}
