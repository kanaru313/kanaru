import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/proxy/upstream_headers.dart';

void main() {
  group('safeMediaType', () {
    test('keeps a type with simple parameters', () {
      for (final value in [
        'audio/webm',
        'audio/webm; codecs="opus"',
        'audio/mp4;codecs=mp4a.40.2',
        'VIDEO/MP4',
      ]) {
        expect(safeMediaType(value), value, reason: value);
      }
    });

    test('refuses control characters, a header break included', () {
      expect(safeMediaType('audio/webm\r\nx-evil: 1'), isNull);
      expect(safeMediaType('audio/webm\n'), isNull);
      expect(safeMediaType('audio/webm; codecs="op\tus"'), isNull);
      expect(safeMediaType('audio/webm\x7f'), isNull);
    });

    test('refuses non-ASCII characters, inside a quoted parameter too', () {
      expect(safeMediaType('audio/webm; codecs="opus é"'), isNull);
      expect(safeMediaType('audio/webm; codecs="\u{1F3B5}"'), isNull);
      expect(safeMediaType('audio/wébm'), isNull);
    });

    test('refuses what is not a media type', () {
      for (final value in [null, '', 'audio', 'audio/', '/webm', 'a b/c']) {
        expect(safeMediaType(value), isNull, reason: '$value');
      }
    });
  });

  group('parseContentRange', () {
    test('reads start, end and total', () {
      expect(parseContentRange('bytes 0-99/1000'), (
        start: 0,
        end: 99,
        total: 1000,
      ));
      expect(parseContentRange('bytes 5-9/*'), (start: 5, end: 9, total: null));
    });

    test('refuses other shapes and ends out of order', () {
      for (final value in [
        null,
        'bytes 9-5/100',
        'bytes 0-100/100',
        'bytes */100',
        'items 0-1/2',
      ]) {
        expect(parseContentRange(value), isNull, reason: '$value');
      }
    });

    test('the total of an unsatisfied range', () {
      expect(unsatisfiedRangeTotal('bytes */1234'), 1234);
      expect(unsatisfiedRangeTotal('bytes 0-1/2'), isNull);
    });
  });
}
