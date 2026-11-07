import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/proxy/hls/hls_proxy_playlist.dart';
import 'package:kanaru/core/sources/proxy/hls/hls_snapshot.dart';

import '../../hls/hls_test_support.dart';

String write(List<String> lines, {int rev = 4}) => writeHlsProxyPlaylist(
  HlsSnapshot(parseMedia(media(lines)), rev),
  (name) => 'http://127.0.0.1:9/t/source-plugin/p/i/$name',
);

const _p = 'http://127.0.0.1:9/t/source-plugin/p/i';

void main() {
  test('writes the fixed header, the segments and the end', () {
    expect(
      write([
        '#EXT-X-MEDIA-SEQUENCE:7',
        '#EXTINF:3.5,',
        'a.ts',
        '#EXTINF:4,',
        'b.aac',
      ]),
      '#EXTM3U\n'
      '#EXT-X-VERSION:7\n'
      '#EXT-X-TARGETDURATION:4\n'
      '#EXT-X-MEDIA-SEQUENCE:7\n'
      '#EXT-X-PLAYLIST-TYPE:VOD\n'
      '#EXTINF:3.500,\n'
      '$_p/hls/4/s0.ts\n'
      '#EXTINF:4.000,\n'
      '$_p/hls/4/s1.aac\n'
      '#EXT-X-ENDLIST\n',
    );
  });

  test('the target duration is the longest duration rounded up', () {
    final out = write(['#EXTINF:3.2,', 'a.ts', '#EXTINF:9.001,', 'b.ts']);
    expect(out, contains('#EXT-X-TARGETDURATION:10\n'));
    expect(out, contains('#EXTINF:9.001,\n'));
  });

  test('durations are written with three decimals', () {
    expect(write(['#EXTINF:2.0005,', 'a.ts']), contains('#EXTINF:2.001,\n'));
    expect(write(['#EXTINF:0.1,', 'a.ts']), contains('#EXTINF:0.100,\n'));
  });

  test('a discontinuity is written before its segment', () {
    final out = write([
      '#EXTINF:4,',
      'a.ts',
      '#EXT-X-DISCONTINUITY',
      '#EXTINF:4,',
      'b.ts',
    ]);
    expect(
      out,
      contains('#EXT-X-DISCONTINUITY\n#EXTINF:4.000,\n$_p/hls/4/s1.ts\n'),
    );
    expect('#EXT-X-DISCONTINUITY'.allMatches(out), hasLength(1));
  });

  test('key rotation, METHOD=NONE and the IV as given', () {
    final out = write([
      '#EXT-X-KEY:METHOD=AES-128,URI="k1"',
      '#EXTINF:4,',
      'a.ts',
      '#EXTINF:4,',
      'b.ts',
      '#EXT-X-KEY:METHOD=AES-128,URI="k2",IV=0x000102030405060708090A0B0C0D0E0F',
      '#EXTINF:4,',
      'c.ts',
      '#EXT-X-KEY:METHOD=NONE',
      '#EXTINF:4,',
      'd.ts',
    ]);
    expect(
      out,
      '#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-TARGETDURATION:4\n'
      '#EXT-X-MEDIA-SEQUENCE:0\n#EXT-X-PLAYLIST-TYPE:VOD\n'
      '#EXT-X-KEY:METHOD=AES-128,URI="$_p/hls/4/k0.key"\n'
      '#EXTINF:4.000,\n$_p/hls/4/s0.ts\n'
      '#EXTINF:4.000,\n$_p/hls/4/s1.ts\n'
      '#EXT-X-KEY:METHOD=AES-128,URI="$_p/hls/4/k1.key",'
      'IV=0x000102030405060708090a0b0c0d0e0f\n'
      '#EXTINF:4.000,\n$_p/hls/4/s2.ts\n'
      '#EXT-X-KEY:METHOD=NONE\n'
      '#EXTINF:4.000,\n$_p/hls/4/s3.ts\n'
      '#EXT-X-ENDLIST\n',
    );
  });

  test('an init section is written once and again when it changes', () {
    final out = write([
      '#EXT-X-MAP:URI="i1.mp4",BYTERANGE="100@0"',
      '#EXTINF:4,',
      'a.m4s',
      '#EXTINF:4,',
      'b.m4s',
      '#EXT-X-MAP:URI="i2.mp4"',
      '#EXTINF:4,',
      'c.m4s',
    ]);
    expect(
      out,
      contains(
        '#EXT-X-MAP:URI="$_p/hls/4/i0.mp4"\n#EXTINF:4.000,\n$_p/hls/4/s0.m4s\n'
        '#EXTINF:4.000,\n$_p/hls/4/s1.m4s\n'
        '#EXT-X-MAP:URI="$_p/hls/4/i1.mp4"\n#EXTINF:4.000,\n$_p/hls/4/s2.m4s\n',
      ),
    );
    expect('#EXT-X-MAP'.allMatches(out), hasLength(2));
  });

  test(
    'byte-range segments become plain URLs, no BYTERANGE, no upstream URL',
    () {
      final out = write([
        '#EXTINF:4,',
        '#EXT-X-BYTERANGE:1000@0',
        'one.ts',
        '#EXTINF:4,',
        '#EXT-X-BYTERANGE:1000',
        'one.ts',
      ]);
      expect(out, isNot(contains('BYTERANGE')));
      expect(out, isNot(contains('one.ts')));
      expect(out, contains('$_p/hls/4/s0.ts\n'));
      expect(out, contains('$_p/hls/4/s1.ts\n'));
    },
  );

  test('only proxy URLs are written', () {
    final out = write([
      '#EXT-X-KEY:METHOD=AES-128,URI="https://cdn.example.com/k"',
      '#EXT-X-MAP:URI="https://cdn.example.com/i.mp4"',
      '#EXTINF:4,',
      'https://cdn.example.com/a.m4s',
    ]);
    expect(out, isNot(contains('example.com')));
    final uris = out
        .split('\n')
        .where((l) => l.isNotEmpty && !l.startsWith('#'));
    expect(uris.every((l) => l.startsWith(_p)), isTrue);
  });

  test('writes nothing from the upstream tags that are not listed', () {
    final out = write([
      '#EXT-X-PROGRAM-DATE-TIME:2026-01-01T00:00:00Z',
      '#EXT-X-DISCONTINUITY-SEQUENCE:3',
      '#EXTINF:4,Some title',
      'a.ts',
    ]);
    expect(out, isNot(contains('PROGRAM-DATE-TIME')));
    expect(out, isNot(contains('DISCONTINUITY')));
    expect(out, isNot(contains('Some title')));
  });

  group('the key in force at each init section', () {
    const k1 = '#EXT-X-KEY:METHOD=AES-128,URI="k1.key"';
    const k2 = '#EXT-X-KEY:METHOD=AES-128,URI="k2.key"';
    const none = '#EXT-X-KEY:METHOD=NONE';
    const map = '#EXT-X-MAP:URI="init.mp4"';
    const key0 = '#EXT-X-KEY:METHOD=AES-128,URI="$_p/hls/4/k0.key"\n';
    const map0 = '#EXT-X-MAP:URI="$_p/hls/4/i0.mp4"\n';

    /// The lines after the fixed header.
    List<String> body(List<String> lines) =>
        write(lines)
            .split('\n')
            .skip(5)
            .where((l) => !l.startsWith('#EXTINF'))
            .toList();

    test('a clear init in front of an encrypted segment: MAP, then KEY', () {
      expect(
        write([map, k1, '#EXTINF:4,', 'a.m4s']),
        contains('$map0$key0#EXTINF:4.000,\n$_p/hls/4/s0.m4s\n'),
      );
    });

    test('an encrypted init: KEY, then MAP, no second KEY', () {
      final out = write([
        k1,
        map,
        '#EXTINF:4,',
        'a.m4s',
        '#EXTINF:4,',
        'b.m4s',
      ]);
      expect(out, contains('$key0$map0#EXTINF:4.000,\n$_p/hls/4/s0.m4s\n'));
      expect('#EXT-X-KEY'.allMatches(out), hasLength(1));
    });

    test('a later MAP under the same key gets only its MAP line', () {
      final out = write([
        k1,
        map,
        '#EXTINF:4,',
        'a.m4s',
        '#EXT-X-MAP:URI="init2.mp4"',
        '#EXTINF:4,',
        'b.m4s',
      ]);
      expect(
        out,
        contains(
          '#EXT-X-MAP:URI="$_p/hls/4/i1.mp4"\n#EXTINF:4.000,\n$_p/hls/4/s1.m4s',
        ),
      );
      expect('#EXT-X-KEY'.allMatches(out), hasLength(1));
      expect('#EXT-X-MAP'.allMatches(out), hasLength(2));
    });

    test('a clear init while a key is in force: NONE, MAP, then the KEY', () {
      expect(
        body([k1, '#EXTINF:4,', 'a.m4s', none, map, k1, '#EXTINF:4,', 'b.m4s']),
        [
          '#EXT-X-KEY:METHOD=AES-128,URI="$_p/hls/4/k0.key"',
          '$_p/hls/4/s0.m4s',
          '#EXT-X-KEY:METHOD=NONE',
          '#EXT-X-MAP:URI="$_p/hls/4/i0.mp4"',
          '#EXT-X-KEY:METHOD=AES-128,URI="$_p/hls/4/k0.key"',
          '$_p/hls/4/s1.m4s',
          '#EXT-X-ENDLIST',
          '',
        ],
      );
    });

    test('a key rotation with the init unchanged writes the MAP once', () {
      expect(
        body([k1, map, '#EXTINF:4,', 'a.m4s', k2, '#EXTINF:4,', 'b.m4s']),
        [
          '#EXT-X-KEY:METHOD=AES-128,URI="$_p/hls/4/k0.key"',
          '#EXT-X-MAP:URI="$_p/hls/4/i0.mp4"',
          '$_p/hls/4/s0.m4s',
          '#EXT-X-KEY:METHOD=AES-128,URI="$_p/hls/4/k1.key"',
          '$_p/hls/4/s1.m4s',
          '#EXT-X-ENDLIST',
          '',
        ],
      );
    });

    test('METHOD=NONE between the key and the MAP gives a clear init', () {
      expect(
        body([k1, '#EXTINF:4,', 'a.m4s', none, map, '#EXTINF:4,', 'b.m4s']),
        [
          '#EXT-X-KEY:METHOD=AES-128,URI="$_p/hls/4/k0.key"',
          '$_p/hls/4/s0.m4s',
          '#EXT-X-KEY:METHOD=NONE',
          '#EXT-X-MAP:URI="$_p/hls/4/i0.mp4"',
          '$_p/hls/4/s1.m4s',
          '#EXT-X-ENDLIST',
          '',
        ],
      );
    });
  });

  group('one key line per change of key state', () {
    String key(String uri, [String? iv]) =>
        '#EXT-X-KEY:METHOD=AES-128,URI="$uri"${iv == null ? '' : ',IV=$iv'}';
    String iv(int n) => '0x${n.toRadixString(16).padLeft(32, '0')}';

    test('one key URI with a new IV on each segment: one key file', () {
      final out = write([
        for (var n = 1; n <= 3; n++) ...[
          key('k.key', iv(n)),
          '#EXTINF:4,',
          's$n.ts',
        ],
      ]);
      final lines = out.split('\n').where((l) => l.startsWith('#EXT-X-KEY'));
      expect(lines.toList(), [
        for (var n = 1; n <= 3; n++)
          '#EXT-X-KEY:METHOD=AES-128,URI="$_p/hls/4/k0.key",IV=${iv(n)}',
      ]);
      expect(out, isNot(contains('k1.key')));
    });

    test('two key URIs are two key files', () {
      final out = write([
        key('a.key'),
        '#EXTINF:4,',
        'a.ts',
        key('b.key'),
        '#EXTINF:4,',
        'b.ts',
      ]);
      expect(out, contains('URI="$_p/hls/4/k0.key"'));
      expect(out, contains('URI="$_p/hls/4/k1.key"'));
    });

    test('a key without IV after one with an IV is written without IV', () {
      final out = write([
        key('k.key', iv(9)),
        '#EXTINF:4,',
        'a.ts',
        key('k.key'),
        '#EXTINF:4,',
        'b.ts',
      ]);
      final lines = out.split('\n').where((l) => l.startsWith('#EXT-X-KEY'));
      expect(lines.toList(), [
        '#EXT-X-KEY:METHOD=AES-128,URI="$_p/hls/4/k0.key",IV=${iv(9)}',
        '#EXT-X-KEY:METHOD=AES-128,URI="$_p/hls/4/k0.key"',
      ]);
    });

    test('a repeated key with a derived IV is one state, no second line', () {
      final out = write([
        key('k.key'),
        '#EXTINF:4,',
        'a.ts',
        key('k.key'),
        '#EXTINF:4,',
        'b.ts',
      ]);
      expect('#EXT-X-KEY'.allMatches(out), hasLength(1));
    });
  });
}
