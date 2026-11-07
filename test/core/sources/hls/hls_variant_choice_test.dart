import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/hls/hls_playlist_parser.dart';

import 'hls_test_support.dart';

Uri choose(List<String> lines) => chooseHlsVariant(parseMaster(master(lines)));

String name(Uri uri) => uri.pathSegments.last;

void main() {
  test('audio-only variants win; the highest bandwidth of them', () {
    final uri = choose([
      '#EXT-X-STREAM-INF:BANDWIDTH=9000000,CODECS="avc1.64001f,mp4a.40.2"',
      'video.m3u8',
      '#EXT-X-STREAM-INF:BANDWIDTH=64000,CODECS="mp4a.40.5"',
      'aac-low.m3u8',
      '#EXT-X-STREAM-INF:BANDWIDTH=256000,CODECS="MP4A.40.2"',
      'aac-high.m3u8',
      '#EXT-X-STREAM-INF:BANDWIDTH=999000',
      'unknown.m3u8',
    ]);
    expect(name(uri), 'aac-high.m3u8');
  });

  test('every audio codec family counts as audio', () {
    for (final codec in ['ac-3', 'ec-3', 'opus', 'flac', 'alac', 'mp4a.40.2']) {
      final uri = choose([
        '#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="avc1.4d401e"',
        'v.m3u8',
        '#EXT-X-STREAM-INF:BANDWIDTH=2,CODECS="$codec"',
        'a.m3u8',
      ]);
      expect(name(uri), 'a.m3u8', reason: codec);
    }
  });

  test('a tie goes to the first listed', () {
    final uri = choose([
      '#EXT-X-STREAM-INF:BANDWIDTH=128000,CODECS="mp4a.40.2"',
      'first.m3u8',
      '#EXT-X-STREAM-INF:BANDWIDTH=128000,CODECS="mp4a.40.2"',
      'second.m3u8',
    ]);
    expect(name(uri), 'first.m3u8');
  });

  test('else the audio group of the highest-bandwidth variant with one', () {
    final uri = choose([
      '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="lo",URI="lo-a.m3u8"',
      '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="hi",NAME="a",URI="hi-a.m3u8"',
      '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="hi",NAME="b",AUTOSELECT=YES,'
          'URI="hi-b.m3u8"',
      '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="hi",NAME="c",DEFAULT=YES,'
          'AUTOSELECT=YES,URI="hi-c.m3u8"',
      '#EXT-X-STREAM-INF:BANDWIDTH=1000,CODECS="avc1.4d401e",AUDIO="lo"',
      'v1.m3u8',
      '#EXT-X-STREAM-INF:BANDWIDTH=5000,CODECS="avc1.4d401e",AUDIO="hi"',
      'v2.m3u8',
      '#EXT-X-STREAM-INF:BANDWIDTH=9000,CODECS="avc1.4d401e",AUDIO="gone"',
      'v3.m3u8',
    ]);
    expect(name(uri), 'hi-c.m3u8');
  });

  test('in the group: AUTOSELECT without DEFAULT, else the first listed', () {
    final autoselect = choose([
      '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="g",URI="first.m3u8"',
      '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="g",AUTOSELECT=YES,URI="auto.m3u8"',
      '#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="avc1.4d401e",AUDIO="g"',
      'v.m3u8',
    ]);
    expect(name(autoselect), 'auto.m3u8');
    final first = choose([
      '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="g",URI="first.m3u8"',
      '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="g",URI="second.m3u8"',
      '#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="avc1.4d401e",AUDIO="g"',
      'v.m3u8',
    ]);
    expect(name(first), 'first.m3u8');
  });

  test('renditions without URI and non-audio renditions are not chosen', () {
    final uri = choose([
      '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="g",DEFAULT=YES',
      '#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="g",URI="video.m3u8"',
      '#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="avc1.4d401e,mp4a.40.2",AUDIO="g"',
      'muxed.m3u8',
    ]);
    expect(name(uri), 'muxed.m3u8');
  });

  test('else the lowest-bandwidth variant that may carry audio', () {
    final uri = choose([
      '#EXT-X-STREAM-INF:BANDWIDTH=100,CODECS="avc1.4d401e"',
      'video-only.m3u8',
      '#EXT-X-STREAM-INF:BANDWIDTH=3000,CODECS="avc1.4d401e,mp4a.40.2"',
      'hi.m3u8',
      '#EXT-X-STREAM-INF:BANDWIDTH=900,CODECS="avc1.4d401e,mp4a.40.2"',
      'lo.m3u8',
      '#EXT-X-STREAM-INF:BANDWIDTH=2000',
      'no-codecs.m3u8',
    ]);
    expect(name(uri), 'lo.m3u8');
  });

  test('a missing BANDWIDTH counts as 0 (the lowest)', () {
    final uri = choose([
      '#EXT-X-STREAM-INF:BANDWIDTH=500',
      'a.m3u8',
      '#EXT-X-STREAM-INF:CODECS="avc1.4d401e,mp4a.40.2"',
      'b.m3u8',
    ]);
    expect(name(uri), 'b.m3u8');
  });

  test('only video variants is noAudio', () {
    expectRefused(
      () => choose([
        '#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="avc1.64001f"',
        'a.m3u8',
        '#EXT-X-STREAM-INF:BANDWIDTH=2,CODECS="avc1.64001f,hvc1.1.6.L93"',
        'b.m3u8',
      ]),
      HlsRefusalKind.noAudio,
    );
  });

  test('I-frame playlists are never chosen', () {
    final uri = choose([
      '#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=1,URI="iframes.m3u8"',
      '#EXT-X-STREAM-INF:BANDWIDTH=500,CODECS="mp4a.40.2"',
      'audio.m3u8',
    ]);
    expect(name(uri), 'audio.m3u8');
  });
}
