import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/media_kit_backend.dart';
import 'package:logging/logging.dart';

void main() {
  group('mpvLogLevel', () {
    test('an aborted or failed file open from lavf is FINE', () {
      expect(
        mpvLogLevel('lavf', 'error', 'avformat_open_input() failed'),
        Level.FINE,
      );
    });

    test('the same text from another prefix stays SEVERE', () {
      expect(
        mpvLogLevel('ffmpeg', 'error', 'avformat_open_input() failed'),
        Level.SEVERE,
      );
    });

    test('other lavf lines keep their level', () {
      expect(
        mpvLogLevel('lavf', 'error', 'Failed to create file cache.'),
        Level.SEVERE,
      );
      expect(mpvLogLevel('lavf', 'warn', 'some warning'), Level.WARNING);
    });
  });
}
