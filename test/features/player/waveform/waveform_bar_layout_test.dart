import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/player/waveform/waveform_bar_layout.dart';

Uint8List _levels(int n, [int Function(int i)? at]) =>
    Uint8List.fromList([for (var i = 0; i < n; i++) at?.call(i) ?? 255]);

List<double> _extents(
  Uint8List levels, {
  int lengthSec = 100,
  int durationSec = 100,
  double width = 500,
}) => waveformBarExtents(
  levels: levels,
  length: Duration(seconds: lengthSec),
  duration: Duration(seconds: durationSec),
  width: width,
);

void main() {
  group('waveformBarCount', () {
    test('fits whole bars with gaps, the last ending inside the width', () {
      expect(waveformBarCount(500), 100);
      expect(waveformBarCount(498), 100); // 100 bars need 100*5 - 2 = 498
      expect(waveformBarCount(497), 99);
    });

    test('a width below one bar gives none', () {
      expect(waveformBarCount(2.9), 0);
      expect(waveformBarCount(3), 1);
      expect(waveformBarCount(0), 0);
      expect(waveformBarCount(double.infinity), 0);
    });
  });

  group('waveformBarExtents', () {
    test('level 0 is the minimum and 255 the maximum', () {
      expect(_extents(_levels(100, (_) => 0)).toSet(), {waveformMinExtent});
      expect(_extents(_levels(100)).toSet(), {waveformMaxExtent});
    });

    test('one level fills every bar', () {
      final extents = _extents(Uint8List.fromList([128]));
      expect(extents, hasLength(100));
      expect(extents.toSet(), hasLength(1));
      expect(extents.first, greaterThan(waveformMinExtent));
    });

    test('a louder level never gives a shorter bar', () {
      final quiet = _extents(_levels(100, (_) => 60));
      final loud = _extents(_levels(100, (_) => 200));
      for (var j = 0; j < quiet.length; j++) {
        expect(loud[j], greaterThan(quiet[j]));
      }
    });

    test('bars follow time: a ramp stays non-decreasing', () {
      final extents = _extents(_levels(255, (i) => i));
      for (var j = 1; j < extents.length; j++) {
        expect(extents[j], greaterThanOrEqualTo(extents[j - 1]));
      }
    });

    test('a bar takes the mean level of its time range', () {
      // 1000 levels over 500 px: each bar spans 10 levels. Levels 500-509
      // alternate 255 and 0, so bar 50 averages 127.5.
      final levels = _levels(
        1000,
        (i) => i >= 500 && i < 510 && i.isEven ? 255 : 0,
      );
      final extents = _extents(levels, lengthSec: 1000, durationSec: 1000);
      expect(
        extents[50],
        waveformMinExtent + (waveformMaxExtent - waveformMinExtent) * 0.5,
      );
      expect(extents[49], waveformMinExtent);
      expect(extents[51], waveformMinExtent);
    });

    test('a lone spike is diluted, not lost', () {
      final levels = _levels(1000, (i) => i == 505 ? 255 : 0);
      final extents = _extents(levels, lengthSec: 1000, durationSec: 1000);
      expect(extents[50], greaterThan(waveformMinExtent));
      expect(extents[50], lessThan(waveformMaxExtent));
      expect(extents[49], waveformMinExtent);
    });

    test('a waveform shorter than the duration leaves the last bars flat', () {
      final extents = _extents(_levels(100), lengthSec: 90);
      expect(extents.sublist(0, 90).toSet(), {waveformMaxExtent});
      expect(extents.sublist(90).toSet(), {waveformMinExtent});
    });

    test('a waveform longer than the duration is cut at the duration', () {
      // The first half of the waveform is loud, the second half silent.
      final levels = _levels(100, (i) => i < 50 ? 255 : 0);
      final extents = _extents(levels, lengthSec: 200, durationSec: 100);
      expect(extents.toSet(), {waveformMaxExtent});
    });

    test('no bars for a zero duration, zero length or too narrow a width', () {
      expect(_extents(_levels(10), durationSec: 0), isEmpty);
      expect(_extents(_levels(10), lengthSec: 0), isEmpty);
      expect(_extents(_levels(10), width: 2), isEmpty);
      expect(_extents(Uint8List(0)), isEmpty);
    });
  });
}
