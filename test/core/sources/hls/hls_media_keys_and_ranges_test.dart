import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/hls/hls_playlist_parser.dart';

import 'hls_test_support.dart';

const _iv = '0x000102030405060708090A0B0C0D0E0F';
final _ivBytes = List.generate(16, (i) => i);

void main() {
  group('keys', () {
    test('AES-128 with URI and IV; the IV is 16 bytes', () {
      final key = parseMedia(
        media([
          '#EXT-X-KEY:METHOD=AES-128,URI="k.key",IV=$_iv',
          '#EXTINF:4,',
          's.ts',
        ]),
      ).segments.single.key!;
      expect(key.uri, Uri.parse('https://cdn.example.com/audio/k.key'));
      expect(key.iv, _ivBytes);
    });

    test('a lower-case hex IV and a 0X prefix are accepted', () {
      for (final iv in [
        '0x000102030405060708090a0b0c0d0e0f',
        '0X000102030405060708090A0B0C0D0E0F',
      ]) {
        final key = parseMedia(
          media([
            '#EXT-X-KEY:METHOD=AES-128,URI="k",IV=$iv',
            '#EXTINF:4,',
            's.ts',
          ]),
        ).segments.single.key!;
        expect(key.iv, _ivBytes);
      }
    });

    test('without IV it stays null (derived from the media sequence)', () {
      final key = parseMedia(
        media(['#EXT-X-KEY:METHOD=AES-128,URI="k"', '#EXTINF:4,', 's.ts']),
      ).segments.single.key!;
      expect(key.iv, isNull);
    });

    test('KEYFORMAT="identity" is accepted', () {
      final segments = parseMedia(
        media([
          '#EXT-X-KEY:METHOD=AES-128,URI="k",KEYFORMAT="identity",'
              'KEYFORMATVERSIONS="1"',
          '#EXTINF:4,',
          's.ts',
        ]),
      ).segments;
      expect(segments.single.key, isNotNull);
    });

    test('rotation: each segment has the key in force; NONE ends it', () {
      final segments = parseMedia(
        media([
          '#EXTINF:4,',
          'a.ts',
          '#EXT-X-KEY:METHOD=AES-128,URI="k1"',
          '#EXTINF:4,',
          'b.ts',
          '#EXTINF:4,',
          'c.ts',
          '#EXT-X-KEY:METHOD=AES-128,URI="k2"',
          '#EXTINF:4,',
          'd.ts',
          '#EXT-X-KEY:METHOD=NONE',
          '#EXTINF:4,',
          'e.ts',
        ]),
      ).segments;
      String? name(HlsSegment s) => s.key?.uri.pathSegments.last;
      expect(segments.map(name), [null, 'k1', 'k1', 'k2', null]);
      expect(segments[1].key, segments[2].key); // equal keys compare equal
      expect(segments[1].key, isNot(segments[3].key));
    });

    test('SAMPLE-AES, SAMPLE-AES-CTR and unknown methods are protected', () {
      for (final method in ['SAMPLE-AES', 'SAMPLE-AES-CTR', 'MAGIC']) {
        expectRefused(
          () => parseText(
            media(['#EXT-X-KEY:METHOD=$method,URI="k"', '#EXTINF:4,', 's.ts']),
          ),
          HlsRefusalKind.protected,
        );
      }
    });

    test('a KEYFORMAT other than identity is protected', () {
      for (final format in [
        'com.apple.streamingkeydelivery',
        'urn:uuid:edef8ba9-79d6-4ace-a3c8-27dcd51d21ed',
      ]) {
        expectRefused(
          () => parseText(
            media([
              '#EXT-X-KEY:METHOD=AES-128,URI="k",KEYFORMAT="$format"',
              '#EXTINF:4,',
              's.ts',
            ]),
          ),
          HlsRefusalKind.protected,
        );
      }
    });

    test('a key without METHOD, URI or with a bad IV is invalid', () {
      for (final tag in [
        '#EXT-X-KEY:URI="k"',
        '#EXT-X-KEY:METHOD=AES-128',
        '#EXT-X-KEY:METHOD=AES-128,URI="k",IV=0x1234',
        '#EXT-X-KEY:METHOD=AES-128,URI="k",IV=000102030405060708090A0B0C0D0E0F',
        '#EXT-X-KEY:METHOD=AES-128,URI="k",IV=0xZZ0102030405060708090A0B0C0D0E0F',
        '#EXT-X-KEY:METHOD=AES-128,URI=""',
        '#EXT-X-KEY',
      ]) {
        expectRefused(
          () => parseText(media([tag, '#EXTINF:4,', 's.ts'])),
          HlsRefusalKind.invalid,
        );
      }
    });
  });

  group('byte ranges', () {
    test('with an offset, and implicit offsets after the same URI', () {
      final segments = parseMedia(
        media([
          '#EXTINF:4,',
          '#EXT-X-BYTERANGE:1000@0',
          'one.aac',
          '#EXTINF:4,',
          '#EXT-X-BYTERANGE:500',
          'one.aac',
          '#EXTINF:4,',
          '#EXT-X-BYTERANGE:300@5000',
          'one.aac',
          '#EXTINF:4,',
          '#EXT-X-BYTERANGE:50',
          'one.aac',
          '#EXTINF:4,',
          'plain.aac',
        ]),
      ).segments;
      expect(
        segments.map(
          (s) => s.byteRange == null
              ? null
              : (s.byteRange!.offset, s.byteRange!.length),
        ),
        [(0, 1000), (1000, 500), (5000, 300), (5300, 50), null],
      );
    });

    test('BYTERANGE before EXTINF works too', () {
      final segment = parseMedia(
        media(['#EXT-X-BYTERANGE:10@20', '#EXTINF:4,', 's.aac']),
      ).segments.single;
      expect((segment.byteRange!.offset, segment.byteRange!.length), (20, 10));
    });

    test('no offset after another URI or after no range is invalid', () {
      for (final lines in [
        [
          '#EXTINF:4,',
          '#EXT-X-BYTERANGE:10@0',
          'a.aac',
          '#EXTINF:4,',
          '#EXT-X-BYTERANGE:10',
          'b.aac',
        ],
        ['#EXTINF:4,', 'a.aac', '#EXTINF:4,', '#EXT-X-BYTERANGE:10', 'a.aac'],
        ['#EXTINF:4,', '#EXT-X-BYTERANGE:10', 'a.aac'],
      ]) {
        expectRefused(() => parseText(media(lines)), HlsRefusalKind.invalid);
      }
    });

    test('bad ranges are invalid: length 0, junk, two @, empty', () {
      for (final text in ['0@0', '-1@0', '10@x', '1@2@3', '', 'a', '1@']) {
        expectRefused(
          () => parseText(
            media(['#EXT-X-BYTERANGE:$text', '#EXTINF:4,', 's.aac']),
          ),
          HlsRefusalKind.invalid,
        );
      }
    });

    test('an end past 2^53 is invalid, also through implicit offsets', () {
      const big = '999999999999999';
      // A 16-digit number is over the digit cap, so it is invalid as well.
      expectRefused(
        () => parseText(
          media(['#EXT-X-BYTERANGE:1@9007199254740992', '#EXTINF:4,', 's.aac']),
        ),
        HlsRefusalKind.invalid,
      );
      final chain = <String>[
        '#EXTINF:4,',
        '#EXT-X-BYTERANGE:$big@0',
        'a.aac',
        for (var i = 0; i < 10; i++) ...[
          '#EXTINF:4,',
          '#EXT-X-BYTERANGE:$big',
          'a.aac',
        ],
      ];
      expectRefused(() => parseText(media(chain)), HlsRefusalKind.invalid);
    });
  });

  group('init sections', () {
    test('EXT-X-MAP applies to the segments after it, with its byte range', () {
      final segments = parseMedia(
        media([
          '#EXT-X-MAP:URI="init.mp4",BYTERANGE="720@0"',
          '#EXTINF:4,',
          'a.m4s',
          '#EXTINF:4,',
          'b.m4s',
          '#EXT-X-DISCONTINUITY',
          '#EXT-X-MAP:URI="init2.mp4"',
          '#EXTINF:4,',
          'c.m4s',
        ]),
      ).segments;
      final first = segments[0].init!;
      expect(first.uri, Uri.parse('https://cdn.example.com/audio/init.mp4'));
      expect((first.byteRange!.offset, first.byteRange!.length), (0, 720));
      expect(segments[1].init, first);
      final changed = segments[2].init!;
      expect(changed.uri.pathSegments.last, 'init2.mp4');
      expect(changed.byteRange, isNull);
      expect(changed, isNot(first));
    });

    test('segments before any EXT-X-MAP have no init section', () {
      final segments = parseMedia(
        media([
          '#EXTINF:4,',
          'a.ts',
          '#EXT-X-MAP:URI="i.mp4"',
          '#EXTINF:4,',
          'b.m4s',
        ]),
      ).segments;
      expect(segments.map((s) => s.init == null), [true, false]);
    });

    test(
      'a MAP without URI, or with a bad or offset-less range, is invalid',
      () {
        for (final tag in [
          '#EXT-X-MAP:BYTERANGE="10@0"',
          '#EXT-X-MAP:URI="i.mp4",BYTERANGE="10"',
          '#EXT-X-MAP:URI="i.mp4",BYTERANGE="x@0"',
          '#EXT-X-MAP',
        ]) {
          expectRefused(
            () => parseText(media([tag, '#EXTINF:4,', 's.m4s'])),
            HlsRefusalKind.invalid,
          );
        }
      },
    );
  });
}
