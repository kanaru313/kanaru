import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/proxy/range_request.dart';

void main() {
  group('parse', () {
    test('no header or a blank one asks for the whole body', () {
      expect(RangeRequest.parse(null), isA<WholeBody>());
      expect(RangeRequest.parse('  '), isA<WholeBody>());
      expect(RangeRequest.parse(null).partial, isFalse);
    });

    test('a closed range', () {
      final range = RangeRequest.parse('bytes=10-19') as ByteRange;
      expect((range.start, range.end), (10, 19));
      expect(range.partial, isTrue);
    });

    test('an open range', () {
      final range = RangeRequest.parse('bytes=512-') as ByteRange;
      expect((range.start, range.end), (512, null));
    });

    test('a suffix range', () {
      final range = RangeRequest.parse('bytes=-250') as SuffixRange;
      expect(range.length, 250);
    });

    test('several ranges, another unit and malformed ones are refused', () {
      for (final header in [
        'bytes=0-1,5-6',
        'items=0-1',
        'bytes=5-2',
        'bytes=-0',
        'bytes=-',
        'bytes=a-b',
        'bytes=0-1\r\nx: y',
        'bytes=9999999999999999-',
      ]) {
        expect(
          RangeRequest.parse(header),
          isA<UnsatisfiableRange>(),
          reason: header,
        );
      }
    });
  });

  group('within', () {
    test('a closed range is cut to the body', () {
      expect(const ByteRange(10, 19).within(100), (start: 10, end: 19));
      expect(const ByteRange(90, 500).within(100), (start: 90, end: 99));
    });

    test('an open range runs to the last byte', () {
      expect(const ByteRange(40).within(100), (start: 40, end: 99));
    });

    test('a range starting past the end cannot be served', () {
      expect(const ByteRange(100).within(100), isNull);
      expect(const ByteRange(150, 160).within(100), isNull);
    });

    test('a suffix range takes the last bytes, at most all of them', () {
      expect(const SuffixRange(10).within(100), (start: 90, end: 99));
      expect(const SuffixRange(500).within(100), (start: 0, end: 99));
    });

    test('an empty body has no byte to serve', () {
      expect(const WholeBody().within(0), isNull);
      expect(const SuffixRange(5).within(0), isNull);
      expect(const WholeBody().within(3), (start: 0, end: 2));
    });
  });
}
