import 'dart:math' as math;
import 'dart:typed_data';

/// Percentile of a track's levels that maps to 0 (the quietest tenth).
const waveformContrastFloorPercentile = 10;

/// Percentile of a track's levels that maps to full height.
const waveformContrastCeilingPercentile = 99;

/// Curve of the stretch: 1.0 keeps linear loudness.
const waveformContrastGamma = 1.0;

/// Below this share of the ceiling the floor and ceiling count as one value
/// (a steady tone): the floor drops to silence and the level just fills up.
const _flatSpreadShare = 0.05;

/// [levels] spread so the track's quieter tenth maps to 0 and its loudest
/// percent to 255. Same length; the input is not modified.
///
/// A stored level `l` is `255 * sqrt(rms / loudest)`, so the linear loudness
/// is `x = (l / 255)^2`. The floor and ceiling levels are found with a
/// 256-bin histogram (nearest rank, no sort); percentiles of `l` are those of
/// `x` because squaring keeps the order. Each level then becomes
/// `255 * clamp((x - xlo) / (xhi - xlo), 0, 1)^gamma`, through a 256-entry
/// table. A ceiling of 0 (a mostly silent file) falls back to the loudest
/// level so a short sound survives; silence stays all zeros; a flat track
/// stays at full height.
Uint8List waveformContrastLevels(Uint8List levels) {
  final n = levels.length;
  if (n == 0) return Uint8List(0);
  final histogram = List<int>.filled(256, 0);
  for (final l in levels) {
    histogram[l]++;
  }

  // The level at sorted position [rank], found by walking the histogram.
  int levelAt(int rank) {
    var seen = 0;
    for (var l = 0; l < 256; l++) {
      seen += histogram[l];
      if (seen > rank) return l;
    }
    return 255;
  }

  int rankOf(int percentile) => (percentile / 100 * (n - 1)).round();
  final lo = levelAt(rankOf(waveformContrastFloorPercentile));
  var hi = levelAt(rankOf(waveformContrastCeilingPercentile));
  if (hi == 0) hi = levelAt(n - 1);
  if (hi == 0) return Uint8List(n);

  double linear(int l) => math.pow(l / 255, 2).toDouble();
  var xlo = linear(lo);
  final xhi = linear(hi);
  if (xhi - xlo < _flatSpreadShare * xhi) xlo = 0;

  final table = Uint8List(256);
  for (var l = 0; l < 256; l++) {
    final t = ((linear(l) - xlo) / (xhi - xlo)).clamp(0.0, 1.0);
    table[l] = (255 * math.pow(t, waveformContrastGamma)).round();
  }
  final out = Uint8List(n);
  for (var i = 0; i < n; i++) {
    out[i] = table[levels[i]];
  }
  return out;
}
