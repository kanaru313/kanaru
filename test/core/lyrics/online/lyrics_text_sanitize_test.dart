import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_text_sanitize.dart';

void main() {
  group('sanitizeLyricsText', () {
    test('drops C0 controls and DEL but keeps newline and tab', () {
      expect(
        sanitizeLyricsText('So\u0000ng\u0007\u007F\u001F\n\tok\u0001'),
        'Song\n\tok',
      );
    });

    test('drops bidirectional overrides and isolates', () {
      expect(sanitizeLyricsText('a\u202Ab\u202Ec\u2066d\u2069e'), 'abcde');
    });

    test('drops carriage returns, keeps ordinary and non-Latin text', () {
      expect(
        sanitizeLyricsText('[00:01.00] Ngân Ngân\r\n歌詞'),
        '[00:01.00] Ngân Ngân\n歌詞',
      );
    });
  });
}
