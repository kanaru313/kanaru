import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/cover_colors/rust_cover_color_extractor.dart';
import 'package:kanaru/src/rust/api/cover_colors.dart' as native;

void main() {
  test('without a cover folder every key fails and nothing loads', () async {
    const extractor = RustCoverColorExtractor(coverDirectory: null);
    final samples = await extractor.extract([
      'ab/x.jpg',
      'cd/y.jpg',
    ], background: true);
    expect(
      [for (final s in samples) (s.key, s.ok)],
      [('ab/x.jpg', false), ('cd/y.jpg', false)],
    );
  });

  test('an empty key list needs no native call', () async {
    const extractor = RustCoverColorExtractor(coverDirectory: '/tmp/x');
    expect(await extractor.extract([], background: false), isEmpty);
  });

  test('a done result keeps its seed and palette', () {
    final sample = sampleFromNative(
      native.CoverColorResult(
        key: 'k',
        status: native.CoverColorStatus.done,
        seed: 0xFFAA0000,
        palette: Uint32List.fromList([0xFFAA0000, 0xFF0000AA]),
      ),
    );
    expect(sample.ok, isTrue);
    expect(sample.seed, 0xFFAA0000);
    expect(sample.palette, [0xFFAA0000, 0xFF0000AA]);
  });

  test('a failed result carries no colors', () {
    final sample = sampleFromNative(
      native.CoverColorResult(
        key: 'k',
        status: native.CoverColorStatus.failed,
        seed: 123,
        palette: Uint32List.fromList([1]),
      ),
    );
    expect(sample.ok, isFalse);
    expect(sample.seed, 0);
    expect(sample.palette, isEmpty);
  });
}
