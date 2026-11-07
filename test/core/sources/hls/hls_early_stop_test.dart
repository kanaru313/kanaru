import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/hls/hls_limits.dart';
import 'package:kanaru/core/sources/hls/hls_playlist_parser.dart';

import 'hls_test_support.dart';

/// [text] followed by a byte that is not UTF-8. A parser that lexes the whole
/// body refuses it as `invalid`; one that stops at a passed count bound never
/// reads it and answers `tooLarge`.
List<int> _thenBadByte(String text) => [...utf8.encode(text), 0xFF];

void main() {
  test('a 4 MiB body of short segments is tooLarge', () {
    const pair = '#EXTINF:1,\na\n';
    final body = '#EXTM3U\n${pair * (hlsMaxPlaylistBytes ~/ pair.length)}';
    expect(body.length, greaterThan(hlsMaxPlaylistBytes - pair.length));
    expectRefused(
      () => parseHlsPlaylist(utf8.encode(body), testBase),
      HlsRefusalKind.tooLarge,
    );
  });

  test('the lexer stops at the first segment past the bound', () {
    String pairs(int count) =>
        '#EXTM3U\n${'#EXTINF:1,\na\n' * count}#EXT-X-ENDLIST\n';
    expectRefused(
      () => parseHlsPlaylist(_thenBadByte(pairs(hlsMaxSegments + 1)), testBase),
      HlsRefusalKind.tooLarge,
    );
    // At the bound the whole body is read, so the bad byte shows.
    expectRefused(
      () => parseHlsPlaylist(_thenBadByte(pairs(hlsMaxSegments)), testBase),
      HlsRefusalKind.invalid,
    );
    expect(
      parseMedia(pairs(hlsMaxSegments)).segments,
      hasLength(hlsMaxSegments),
    );
  });

  test('the lexer stops at the first variant past the bound', () {
    String variants(int count) =>
        '#EXTM3U\n${'#EXT-X-STREAM-INF:BANDWIDTH=1\nv.m3u8\n' * count}';
    expectRefused(
      () => parseHlsPlaylist(
        _thenBadByte(variants(hlsMaxVariants + 1)),
        testBase,
      ),
      HlsRefusalKind.tooLarge,
    );
    expectRefused(
      () => parseHlsPlaylist(_thenBadByte(variants(hlsMaxVariants)), testBase),
      HlsRefusalKind.invalid,
    );
  });

  test('the lexer stops at the first rendition past the bound', () {
    String renditions(int count) =>
        '#EXTM3U\n'
        '${'#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",URI="r.m3u8"\n' * count}'
        '#EXT-X-STREAM-INF:BANDWIDTH=1\nv.m3u8\n';
    expectRefused(
      () => parseHlsPlaylist(
        _thenBadByte(renditions(hlsMaxRenditions + 1)),
        testBase,
      ),
      HlsRefusalKind.tooLarge,
    );
    expectRefused(
      () => parseHlsPlaylist(
        _thenBadByte(renditions(hlsMaxRenditions)),
        testBase,
      ),
      HlsRefusalKind.invalid,
    );
  });
}
