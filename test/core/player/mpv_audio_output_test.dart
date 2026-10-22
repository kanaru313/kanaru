import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/mpv_audio_output.dart';
import 'package:kanaru/core/player/mpv_startup_options.dart';

void main() {
  group('isAudioOpenFailure', () {
    test('matches the line mpv prints when the output does not open', () {
      expect(
        isAudioOpenFailure(
          'Could not open/initialize audio device -> no sound.',
        ),
        isTrue,
      );
    });

    test('ignores other lines', () {
      expect(isAudioOpenFailure('Audio device changed'), isFalse);
      expect(isAudioOpenFailure(''), isFalse);
    });
  });

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
