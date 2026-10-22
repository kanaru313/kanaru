import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/m3u/m3u_parse.dart';

Uint8List _bytes(List<int> list) => Uint8List.fromList(list);

void main() {
  group('decodeM3uBytes', () {
    test('drops the UTF-8 byte order mark', () {
      final bytes = _bytes([0xEF, 0xBB, 0xBF, ...utf8.encode('/m/ả.mp3')]);
      expect(decodeM3uBytes(bytes), '/m/ả.mp3');
    });

    test('falls back to Latin-1 when the bytes are not UTF-8', () {
      final bytes = _bytes([
        ...ascii.encode('/m/caf'),
        0xE9,
        ...ascii.encode('.mp3'),
      ]);
      expect(decodeM3uBytes(bytes), '/m/café.mp3');
    });
  });

  group('m3uPathLines', () {
    test('skips comments and blank lines and keeps line numbers', () {
      final parsed = m3uPathLines(
        '#EXTM3U\r\n#EXTINF:10,A - B\r\n/m/a.mp3\r\n\r\n   \r\nb.flac\r\n',
      );
      expect(parsed.truncated, isFalse);
      expect(
        [for (final l in parsed.lines) (l.line, l.text, l.tooLong)],
        [(3, '/m/a.mp3', false), (6, 'b.flac', false)],
      );
    });

    test('marks a line over the byte limit as too long', () {
      final long = 'a' * 5000;
      expect(m3uPathLines('$long\n').lines.single.tooLong, isTrue);
      // Multi-byte characters count in bytes.
      final wide = 'ả' * 2000; // 3 bytes each in UTF-8
      expect(m3uPathLines(wide).lines.single.tooLong, isTrue);
    });

    test('stops after the line limit', () {
      final text = List.filled(m3uMaxPathLines + 1, 'x.mp3').join('\n');
      final parsed = m3uPathLines(text);
      expect(parsed.lines, hasLength(m3uMaxPathLines));
      expect(parsed.truncated, isTrue);
    });

    test('exactly the limit is not truncated', () {
      final text = List.filled(m3uMaxPathLines, 'x.mp3').join('\n');
      expect(m3uPathLines(text).truncated, isFalse);
    });
  });
}
