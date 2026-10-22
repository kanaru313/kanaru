import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/cover_colors/cover_palette.dart';
import 'package:kanaru/core/paths/app_directories.dart';

void main() {
  group('palette text', () {
    test('round-trips 1, 5 and 8 colors in order', () {
      for (final count in [1, 5, 8]) {
        final argb = [for (var i = 0; i < count; i++) 0xFF000000 | i * 0x10203];
        final text = encodePalette(argb);
        expect(text, matches(RegExp(r'^[0-9a-f]{8}(,[0-9a-f]{8})*$')));
        expect(decodePalette(text), [for (final c in argb) Color(c)]);
      }
    });

    test('is lowercase, zero-padded hex', () {
      expect(encodePalette([0xFFAABBCC, 0x0000000F]), 'ffaabbcc,0000000f');
    });

    test('anything but the exact stored format reads as missing', () {
      for (final bad in [
        '',
        'zz',
        'FFAABBCC',
        'ffaabbcc,',
        ',ffaabbcc',
        'ffaabbcc, ff000000',
        ' ffaabbcc',
        'ffaabbc',
        'ffaabbccd',
        List.filled(9, 'ff000000').join(','),
      ]) {
        expect(decodePalette(bad), isNull, reason: bad);
      }
    });
  });

  group('stored rows', () {
    test('seed 0 is a gray cover: no seed, colors kept', () {
      final palette = paletteFromRow(seed: 0, palette: 'ff808080');
      expect(palette, isNotNull);
      expect(palette!.seed, isNull);
      expect(palette.colors, [const Color(0xFF808080)]);
    });

    test('an opaque seed is used as is', () {
      final palette = paletteFromRow(seed: 0xFFCC2233, palette: 'ffcc2233');
      expect(palette!.seed, const Color(0xFFCC2233));
    });

    test('a seed that is not opaque, or out of range, is a damaged row', () {
      for (final seed in [0x80FF0000, 0x00FF0000, -1, 0x1FFFFFFFF]) {
        expect(
          paletteFromRow(seed: seed, palette: 'ffcc2233'),
          isNull,
          reason: seed.toRadixString(16),
        );
      }
    });

    test('a damaged palette is a damaged row', () {
      expect(paletteFromRow(seed: 0xFFCC2233, palette: 'nope'), isNull);
    });
  });

  test('palettes with the same colors are equal', () {
    const a = CoverPalette(
      seed: Color(0xFF112233),
      colors: [Color(0xFF112233)],
    );
    const b = CoverPalette(
      seed: Color(0xFF112233),
      colors: [Color(0xFF112233)],
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      a == const CoverPalette(seed: null, colors: [Color(0xFF112233)]),
      isFalse,
    );
  });

  test('the algorithm version includes the thumbnail size', () {
    expect(coverColorAlgoVersion % 100000, coverThumbnailSize);
    expect(coverColorAlgoVersion ~/ 100000, coverColorAlgoRevision);
  });
}
