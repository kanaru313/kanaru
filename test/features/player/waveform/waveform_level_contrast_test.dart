import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/player/waveform/waveform_level_contrast.dart';

/// The stretch written the slow way: sort, pick by rank, map each level.
Uint8List _reference(Uint8List levels) {
  final sorted = List<int>.of(levels)..sort();
  final n = sorted.length;
  int at(int p) => sorted[(p / 100 * (n - 1)).round()];
  final lo = at(waveformContrastFloorPercentile);
  var hi = at(waveformContrastCeilingPercentile);
  if (hi == 0) hi = sorted.last;
  if (hi == 0) return Uint8List(n);
  double lin(int l) => pow(l / 255, 2).toDouble();
  var xlo = lin(lo);
  final xhi = lin(hi);
  if (xhi - xlo < 0.05 * xhi) xlo = 0;
  return Uint8List.fromList([
    for (final l in levels)
      (255 * ((lin(l) - xlo) / (xhi - xlo)).clamp(0.0, 1.0)).round(),
  ]);
}

void main() {
  test('a flat track stays full height', () {
    expect(
      waveformContrastLevels(Uint8List.fromList(List.filled(100, 200))),
      List.filled(100, 255),
    );
    expect(waveformContrastLevels(Uint8List.fromList([128])), [255]);
  });

  test('silence stays zero', () {
    expect(waveformContrastLevels(Uint8List(50)), everyElement(0));
  });

  test('a short sound in silence is kept', () {
    final levels = Uint8List(1000)..[417] = 255;
    final out = waveformContrastLevels(levels);
    expect(out[417], 255);
    expect(out.where((v) => v != 0).length, 1);
  });

  test('a ramp spreads over the full range', () {
    final out = waveformContrastLevels(
      Uint8List.fromList([for (var i = 0; i < 256; i++) i]),
    );
    for (var i = 1; i < out.length; i++) {
      expect(out[i], greaterThanOrEqualTo(out[i - 1]));
    }
    expect(out.sublist(0, 26), everyElement(0));
    expect(out.sublist(252), everyElement(255));
    expect(out[128], inExclusiveRange(0, 255));
  });

  test('the quiet tenth maps to 0 and the loudest percent to 255', () {
    final levels = Uint8List.fromList([
      ...List.filled(101, 160),
      ...List.filled(888, 200),
      ...List.filled(11, 250),
    ]);
    final out = waveformContrastLevels(levels);
    expect(out.first, 0);
    expect(out.last, 255);
    final xlo = pow(160 / 255, 2);
    final xhi = pow(250 / 255, 2);
    final expected = (255 * (pow(200 / 255, 2) - xlo) / (xhi - xlo)).round();
    expect(out[500], closeTo(expected, 1));
  });

  // 100 levels: ten quiet ones (50), 88 at the floor level, two at the ceiling
  // level 200. Ranks 10 and 98 give floor = [floor], ceiling = 200. Squared
  // levels (x255^2): 200 -> 40000, 195 -> 38025, 194 -> 37636; 5 % of 40000
  // is 2000.
  Uint8List nearFlatTrack(int floor) => Uint8List.fromList([
    ...List.filled(10, 50),
    ...List.filled(88, floor),
    ...List.filled(2, 200),
  ]);

  test('a floor just under 5 % of the ceiling drops to silence', () {
    // 40000 - 38025 = 1975 < 2000: near flat, the floor becomes 0, so the
    // floor level keeps a high value: 255 * 38025 / 40000 = 242.4 -> 242.
    final out = waveformContrastLevels(nearFlatTrack(195));
    expect(out[0], 16); // level 50: 255 * 2500 / 40000 = 15.9
    expect(out[50], 242);
    expect(out[99], 255);
  });

  test('a floor just over 5 % of the ceiling is kept', () {
    // 40000 - 37636 = 2364 > 2000: the floor stays, so it maps to 0 and
    // level 197 lands mid range: 255 * (38809 - 37636) / 2364 = 126.5 -> 127.
    final out = waveformContrastLevels(nearFlatTrack(194));
    expect(out[0], 0);
    expect(out[50], 0);
    expect(out[99], 255);
    final mid = nearFlatTrack(194)..[50] = 197;
    expect(waveformContrastLevels(mid)[50], closeTo(127, 1));
  });

  test('matches a sort based reference on random tracks', () {
    final random = Random(1);
    for (final n in [1, 2, 7, 120, 1000]) {
      for (final top in [10, 120, 255]) {
        final levels = Uint8List.fromList([
          for (var i = 0; i < n; i++) random.nextInt(top + 1),
        ]);
        expect(waveformContrastLevels(levels), _reference(levels));
      }
    }
  });

  test('a louder level never maps lower', () {
    final random = Random(1);
    final levels = Uint8List.fromList([
      for (var i = 0; i < 2000; i++) 60 + random.nextInt(196),
    ]);
    final out = waveformContrastLevels(levels);
    final byLevel = <int, int>{};
    for (var i = 0; i < levels.length; i++) {
      expect(byLevel.putIfAbsent(levels[i], () => out[i]), out[i]);
    }
    final keys = byLevel.keys.toList()..sort();
    for (var i = 1; i < keys.length; i++) {
      expect(byLevel[keys[i]]!, greaterThanOrEqualTo(byLevel[keys[i - 1]]!));
    }
  });

  test('keeps the length and leaves the input alone', () {
    final levels = Uint8List.fromList([for (var i = 0; i < 90; i++) i * 2]);
    final copy = Uint8List.fromList(levels);
    final out = waveformContrastLevels(levels);
    expect(out.length, levels.length);
    expect(levels, copy);
    expect(identical(out, levels), isFalse);
  });

  test('an empty track gives an empty result', () {
    expect(waveformContrastLevels(Uint8List(0)), isEmpty);
  });
}
