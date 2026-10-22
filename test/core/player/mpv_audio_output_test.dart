import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/mpv_startup_options.dart';

void main() {
  group('mpvStartupOptions', () {
    test('stops mpv from following references inside a file', () {
      expect(mpvStartupOptions, contains(('access-references', 'no')));
    });

    test('keeps gapless audio and the memory cache', () {
      expect(mpvStartupOptions, contains(('gapless-audio', 'weak')));
      expect(mpvStartupOptions, contains(('cache-on-disk', 'no')));
    });
  });
}
