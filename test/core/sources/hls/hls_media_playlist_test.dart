import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/hls/hls_limits.dart';
import 'package:kanaru/core/sources/hls/hls_playlist_parser.dart';

import 'hls_test_support.dart';

List<String> _segments(int count, {String duration = '1'}) => [
  for (var i = 0; i < count; i++) ...['#EXTINF:$duration,', 's$i.ts'],
];

void main() {
  group('syntax', () {
    test('LF and CRLF lines, a BOM, blank lines and trailing spaces', () {
      const body =
          '#EXTM3U  \r\n\r\n#EXT-X-TARGETDURATION:4\r\n'
          '#EXTINF:4,  \r\n  seg0.ts  \r\n\r\n#comment\r\n#EXT-X-ENDLIST\r\n';
      final playlist = parseHlsPlaylist([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode(body),
      ], testBase) as HlsMediaPlaylist;
      expect(playlist.segments, hasLength(1));
      expect(
        playlist.segments.single.uri,
        Uri.parse('https://cdn.example.com/audio/seg0.ts'),
      );
      // The same with LF only and no newline at the end.
      expect(
        parseMedia(body.replaceAll('\r', '').trimRight()).segments,
        hasLength(1),
      );
    });

    test('invalid UTF-8 is invalid', () {
      final bytes = [...utf8.encode('#EXTM3U\n#EXTINF:4,\n'), 0xFF, 0x0A];
      expectRefused(
        () => parseHlsPlaylist(bytes, testBase),
        HlsRefusalKind.invalid,
      );
    });

    test('a missing, late or empty #EXTM3U is invalid', () {
      for (final body in [
        '',
        '#EXT-X-TARGETDURATION:4\n#EXTINF:4,\ns.ts\n#EXT-X-ENDLIST',
        '\n#EXTM3U\n#EXTINF:4,\ns.ts\n#EXT-X-ENDLIST',
        '#EXTM3U8\n#EXTINF:4,\ns.ts\n#EXT-X-ENDLIST',
      ]) {
        expectRefused(() => parseText(body), HlsRefusalKind.invalid);
      }
    });

    test('a line over its bound is tooLarge, at the bound it is fine', () {
      final atBound = '#${'x' * (hlsMaxLineBytes - 1)}';
      expect(
        parseMedia(media(['#EXTINF:4,', atBound, 's.ts'])).segments,
        hasLength(1),
      );
      expectRefused(
        () => parseText(media(['#${'x' * hlsMaxLineBytes}'])),
        HlsRefusalKind.tooLarge,
      );
    });

    test('a URI over its bound is tooLarge', () {
      final ok = 'a' * (hlsMaxUriLength - 3);
      expect(
        parseMedia(media(['#EXTINF:4,', '$ok.ts'])).segments,
        hasLength(1),
      );
      expectRefused(
        () => parseText(media(['#EXTINF:4,', '${'a' * hlsMaxUriLength}.ts'])),
        HlsRefusalKind.tooLarge,
      );
    });
  });

  group('segments', () {
    test('relative, root-relative and absolute URIs resolve', () {
      final playlist = parseMedia(
        media([
          '#EXTINF:4,',
          'seg0.ts',
          '#EXTINF:4,',
          '../other/seg1.ts?x=1',
          '#EXTINF:4,',
          '/root/seg2.ts',
          '#EXTINF:4,',
          'https://other.example.org/a/seg3.ts',
          '#EXTINF:4,',
          '//cdn2.example.com/seg4.ts',
        ]),
      );
      expect(playlist.segments.map((s) => s.uri.toString()), [
        'https://cdn.example.com/audio/seg0.ts',
        'https://cdn.example.com/other/seg1.ts?x=1',
        'https://cdn.example.com/root/seg2.ts',
        'https://other.example.org/a/seg3.ts',
        'https://cdn2.example.com/seg4.ts',
      ]);
    });

    test('data: URIs are kept as they are; the host is not judged', () {
      final playlist = parseMedia(
        media(['#EXTINF:4,', 'data:audio/mpeg;base64,AAAA']),
      );
      expect(playlist.segments.single.uri.scheme, 'data');
    });

    test('a URI that cannot be parsed is invalid', () {
      expectRefused(
        () => parseText(media(['#EXTINF:4,', 'http://[::1/seg.ts'])),
        HlsRefusalKind.invalid,
      );
    });

    test('durations: with and without comma, title, sum and sequence', () {
      final playlist = parseMedia(
        '#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:5\n'
        '#EXT-X-MEDIA-SEQUENCE:7\n#EXT-X-DISCONTINUITY-SEQUENCE:2\n'
        '#EXT-X-PLAYLIST-TYPE:VOD\n'
        '#EXTINF:4,\na.ts\n#EXTINF:4.500,Title, with comma\nb.ts\n'
        '#EXTINF:3.25\nc.ts\n#EXT-X-ENDLIST\n',
      );
      expect(playlist.segments.map((s) => s.duration.inMilliseconds), [
        4000,
        4500,
        3250,
      ]);
      expect(playlist.totalDuration, const Duration(milliseconds: 11750));
      expect(playlist.mediaSequence, 7);
      expect(playlist.targetDuration, const Duration(seconds: 5));
    });

    test('without TARGETDURATION it is the longest duration, rounded up', () {
      final playlist = parseMedia(
        '#EXTM3U\n#EXTINF:4.2,\na.ts\n#EXTINF:2,\nb.ts\n#EXT-X-ENDLIST',
      );
      expect(playlist.targetDuration, const Duration(seconds: 5));
      expect(playlist.mediaSequence, 0);
    });

    test('bad durations are invalid', () {
      for (final duration in [
        '-1',
        'NaN',
        'Infinity',
        '0',
        '0.0',
        '3600.001',
        '1e3',
        '',
        'abc',
        '4s',
      ]) {
        expectRefused(
          () => parseText(media(['#EXTINF:$duration,', 's.ts'])),
          HlsRefusalKind.invalid,
        );
      }
      expect(
        parseMedia(media(['#EXTINF:3600,', 's.ts'])).segments,
        hasLength(1),
      );
    });

    test('a total over 24 hours is invalid, 24 hours is fine', () {
      expect(
        parseMedia(media(_segments(24, duration: '3600'))).totalDuration,
        const Duration(hours: 24),
      );
      expectRefused(
        () => parseText(media(_segments(25, duration: '3600'))),
        HlsRefusalKind.invalid,
      );
    });

    test('segment count: the bound is fine, one more is tooLarge', () {
      expect(
        parseMedia(media(_segments(hlsMaxSegments))).segments,
        hasLength(hlsMaxSegments),
      );
      expectRefused(
        () => parseText(media(_segments(hlsMaxSegments + 1))),
        HlsRefusalKind.tooLarge,
      );
    });

    test('discontinuity marks the next segment only', () {
      final playlist = parseMedia(
        media([
          '#EXTINF:4,',
          'a.ts',
          '#EXT-X-DISCONTINUITY',
          '#EXTINF:4,',
          'b.ts',
          '#EXTINF:4,',
          'c.ts',
        ]),
      );
      expect(playlist.segments.map((s) => s.discontinuity), [
        false,
        true,
        false,
      ]);
    });

    test('ignored tags and unknown #EXT tags change nothing', () {
      final playlist = parseMedia(
        media([
          '#EXT-X-PROGRAM-DATE-TIME:2026-01-01T00:00:00Z',
          '#EXT-X-INDEPENDENT-SEGMENTS',
          '#EXT-X-START:TIME-OFFSET=0',
          '#EXT-X-DATERANGE:ID="x"',
          '#EXT-X-FUTURE-TAG:whatever',
          '#EXTINF:4,',
          '#EXT-X-GAP',
          'a.ts',
        ]),
      );
      expect(playlist.segments, hasLength(1));
    });
  });

  group('refusals', () {
    test('no EXT-X-ENDLIST is live, whatever PLAYLIST-TYPE says', () {
      for (final type in [null, 'VOD', 'EVENT']) {
        expectRefused(
          () => parseText(
            media([
              if (type != null) '#EXT-X-PLAYLIST-TYPE:$type',
              '#EXTINF:4,',
              's.ts',
            ], end: false),
          ),
          HlsRefusalKind.live,
        );
      }
    });

    test('PLAYLIST-TYPE:EVENT with EXT-X-ENDLIST plays', () {
      expect(
        parseMedia(media(['#EXT-X-PLAYLIST-TYPE:EVENT', '#EXTINF:4,', 's.ts']))
            .segments,
        hasLength(1),
      );
    });

    test('EXT-X-ENDLIST with no segment is invalid', () {
      expectRefused(() => parseText(media([])), HlsRefusalKind.invalid);
      expectRefused(
        () => parseText(media([], end: false)),
        HlsRefusalKind.invalid,
      );
    });

    test('EXT-X-I-FRAMES-ONLY is noAudio', () {
      expectRefused(
        () => parseText(media(['#EXT-X-I-FRAMES-ONLY', '#EXTINF:4,', 's.ts'])),
        HlsRefusalKind.noAudio,
      );
    });

    test('EXT-X-SKIP and EXT-X-DEFINE are invalid', () {
      for (final tag in [
        '#EXT-X-SKIP:SKIPPED-SEGMENTS=3',
        '#EXT-X-DEFINE:NAME="a",VALUE="b"',
      ]) {
        expectRefused(
          () => parseText(media([tag, '#EXTINF:4,', 's.ts'])),
          HlsRefusalKind.invalid,
        );
      }
    });

    test('EXTINF without a URI line, and a URI line without EXTINF', () {
      expectRefused(
        () => parseText(media(['#EXTINF:4,'])),
        HlsRefusalKind.invalid,
      );
      expectRefused(
        () => parseText(media(['#EXTINF:4,', '#EXTINF:4,', 's.ts'])),
        HlsRefusalKind.invalid,
      );
      expectRefused(
        () => parseText(media(['#EXTINF:4,', 'a.ts', 'b.ts'])),
        HlsRefusalKind.invalid,
      );
    });

    test('bad VERSION, TARGETDURATION, MEDIA-SEQUENCE, PLAYLIST-TYPE', () {
      for (final tag in [
        '#EXT-X-VERSION:x',
        '#EXT-X-TARGETDURATION:0',
        '#EXT-X-TARGETDURATION:4.5',
        '#EXT-X-TARGETDURATION:3601',
        '#EXT-X-TARGETDURATION:999999999999999',
        '#EXT-X-MEDIA-SEQUENCE:-1',
        '#EXT-X-MEDIA-SEQUENCE:',
        '#EXT-X-DISCONTINUITY-SEQUENCE:a',
        '#EXT-X-PLAYLIST-TYPE:LIVE',
      ]) {
        expectRefused(
          () => parseText(media([tag, '#EXTINF:4,', 's.ts'])),
          HlsRefusalKind.invalid,
        );
      }
    });

    test('both STREAM-INF and EXTINF in one playlist is invalid', () {
      expectRefused(
        () => parseText(
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nv.m3u8\n'
          '#EXTINF:4,\ns.ts\n#EXT-X-ENDLIST',
        ),
        HlsRefusalKind.invalid,
      );
    });
  });
}
