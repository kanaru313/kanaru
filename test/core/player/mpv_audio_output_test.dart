import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/mpv_startup_options.dart';

void main() {
  group('mpvStartupOptions', () {
    test('stops mpv from following references inside a file', () {
      expect(mpvStartupOptions, contains(('demuxer', 'lavf')));
      expect(
        mpvStartupOptions,
        contains(('demuxer-lavf-o', 'protocol_whitelist=file')),
      );
      // Refuses media_kit's own `loadlist`, so no track would open.
      expect(
        mpvStartupOptions.map((option) => option.$1),
        isNot(contains('access-references')),
      );
    });

    test('keeps gapless audio and the memory cache', () {
      expect(mpvStartupOptions, contains(('gapless-audio', 'weak')));
      expect(mpvStartupOptions, contains(('cache-on-disk', 'no')));
    });
  });
}
