import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/hls/hls_limits.dart';
import 'package:kanaru/core/sources/hls/hls_playlist_parser.dart';

import 'hls_test_support.dart';

void main() {
  test('variants: bandwidth, codecs, audio group, resolved URIs', () {
    final playlist = parseMaster(
      master([
        '#EXT-X-VERSION:6',
        '#EXT-X-INDEPENDENT-SEGMENTS',
        '#EXT-X-STREAM-INF:BANDWIDTH=128000,CODECS="mp4a.40.2",AUDIO="aud"',
        'low/index.m3u8',
        '#EXT-X-STREAM-INF:BANDWIDTH=2000000,AVERAGE-BANDWIDTH=1,'
            'CODECS="avc1.64001f,mp4a.40.2",RESOLUTION=1280x720',
        'https://other.example.org/hi.m3u8',
        '#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=50000,URI="iframes.m3u8"',
      ]),
    );
    expect(playlist.variants, hasLength(2));
    final low = playlist.variants[0];
    expect(low.uri, Uri.parse('https://cdn.example.com/audio/low/index.m3u8'));
    expect(low.bandwidth, 128000);
    expect(low.codecs, ['mp4a.40.2']);
    expect(low.audioGroup, 'aud');
    final high = playlist.variants[1];
    expect(high.uri.host, 'other.example.org');
    expect(high.codecs, ['avc1.64001f', 'mp4a.40.2']);
    expect(high.audioGroup, isNull);
  });

  test('a missing or bad BANDWIDTH is 0; missing CODECS is null', () {
    final playlist = parseMaster(
      master([
        '#EXT-X-STREAM-INF:CODECS=""',
        'a.m3u8',
        '#EXT-X-STREAM-INF:BANDWIDTH=fast',
        'b.m3u8',
        '#EXT-X-STREAM-INF:BANDWIDTH=-5',
        'c.m3u8',
      ]),
    );
    expect(playlist.variants.map((v) => v.bandwidth), [0, 0, 0]);
    expect(playlist.variants.map((v) => v.codecs), [null, null, null]);
  });

  test('renditions: with and without URI, DEFAULT and AUTOSELECT', () {
    final playlist = parseMaster(
      master([
        '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="En",DEFAULT=YES,'
            'AUTOSELECT=YES,URI="en/index.m3u8"',
        '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="Fr",DEFAULT=NO,'
            'AUTOSELECT=NO,URI="/fr/index.m3u8"',
        '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="Muxed"',
        '#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="sub",URI="s.m3u8"',
        '#EXT-X-MEDIA:NAME="no type or group"',
        '#EXT-X-STREAM-INF:BANDWIDTH=1,AUDIO="aud"',
        'v.m3u8',
      ]),
    );
    expect(playlist.renditions, hasLength(4));
    final en = playlist.renditions[0];
    expect(
      (en.type, en.groupId, en.isDefault, en.isAutoselect),
      ('AUDIO', 'aud', true, true),
    );
    expect(en.uri, Uri.parse('https://cdn.example.com/audio/en/index.m3u8'));
    final fr = playlist.renditions[1];
    expect((fr.isDefault, fr.isAutoselect), (false, false));
    expect(fr.uri, Uri.parse('https://cdn.example.com/fr/index.m3u8'));
    expect(playlist.renditions[2].uri, isNull);
    expect(playlist.renditions[3].type, 'SUBTITLES');
  });

  test('a STREAM-INF without a URI line is invalid', () {
    expectRefused(
      () => parseText(master(['#EXT-X-STREAM-INF:BANDWIDTH=1'])),
      HlsRefusalKind.invalid,
    );
    expectRefused(
      () => parseText(
        master([
          '#EXT-X-STREAM-INF:BANDWIDTH=1',
          '#EXT-X-STREAM-INF:BANDWIDTH=2',
          'a.m3u8',
        ]),
      ),
      HlsRefusalKind.invalid,
    );
  });

  test('a URI line before any STREAM-INF is invalid', () {
    expectRefused(
      () => parseText(
        master(['a.m3u8', '#EXT-X-STREAM-INF:BANDWIDTH=1', 'b.m3u8']),
      ),
      HlsRefusalKind.invalid,
    );
  });

  test('a bad attribute list is invalid', () {
    expectRefused(
      () => parseText(
        master(['#EXT-X-STREAM-INF:BANDWIDTH=1,BANDWIDTH=2', 'a.m3u8']),
      ),
      HlsRefusalKind.invalid,
    );
    expectRefused(
      () =>
          parseText(master(['#EXT-X-STREAM-INF:CODECS="mp4a.40.2', 'a.m3u8'])),
      HlsRefusalKind.invalid,
    );
  });

  test('variants: the bound is fine, one more is tooLarge', () {
    List<String> variants(int n) => [
      for (var i = 0; i < n; i++) ...[
        '#EXT-X-STREAM-INF:BANDWIDTH=$i',
        'v$i.m3u8',
      ],
    ];
    expect(
      parseMaster(master(variants(hlsMaxVariants))).variants,
      hasLength(hlsMaxVariants),
    );
    expectRefused(
      () => parseText(master(variants(hlsMaxVariants + 1))),
      HlsRefusalKind.tooLarge,
    );
  });

  test('renditions: the bound is fine, one more is tooLarge', () {
    List<String> renditions(int n) => [
      for (var i = 0; i < n; i++)
        '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="g$i",URI="r$i.m3u8"',
      '#EXT-X-STREAM-INF:BANDWIDTH=1',
      'v.m3u8',
    ];
    expect(
      parseMaster(master(renditions(hlsMaxRenditions))).renditions,
      hasLength(hlsMaxRenditions),
    );
    expectRefused(
      () => parseText(master(renditions(hlsMaxRenditions + 1))),
      HlsRefusalKind.tooLarge,
    );
  });

  test('a variant URI over its bound is tooLarge', () {
    expectRefused(
      () => parseText(
        master([
          '#EXT-X-STREAM-INF:BANDWIDTH=1',
          '${'a' * hlsMaxUriLength}.m3u8',
        ]),
      ),
      HlsRefusalKind.tooLarge,
    );
  });
}
