import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/proxy/hls/hls_proxy_names.dart';

void main() {
  group('hlsSegmentExt', () {
    String ext(String url, {bool init = false}) =>
        hlsSegmentExt(Uri.parse(url), hasInit: init);

    test('maps the path extension, lower-cased, ignoring the query', () {
      expect(ext('https://h/a/b.TS?x=1.mp3'), 'ts');
      expect(ext('https://h/a.m2ts'), 'ts');
      expect(ext('https://h/a.adts'), 'aac');
      expect(ext('https://h/a.mp3'), 'mp3');
      expect(ext('https://h/a.cmfa'), 'm4s');
      expect(ext('https://h/a.m4a'), 'm4s');
      expect(ext('https://h/a.ac3'), 'ac3');
      expect(ext('https://h/a.eac3'), 'ec3');
    });

    test('otherwise m4s with an init section, ts without', () {
      expect(ext('https://h/a.bin', init: true), 'm4s');
      expect(ext('https://h/a.bin'), 'ts');
      expect(ext('https://h/segment'), 'ts');
      expect(ext('https://h/'), 'ts');
    });
  });

  group('names', () {
    test('are built in one shape', () {
      expect(hlsSegmentName(3, 12, 'aac'), 'hls/3/s12.aac');
      expect(hlsInitName(3, 0), 'hls/3/i0.mp4');
      expect(hlsKeyName(3, 1), 'hls/3/k1.key');
    });

    test('parse back to what they name', () {
      final segment = parseHlsResourceName('hls/7/s0.ts')!;
      expect(
        (segment.kind, segment.rev, segment.index, segment.ext),
        (HlsResourceKind.segment, 7, 0, 'ts'),
      );
      expect(segment.contentType, 'video/mp2t');
      final init = parseHlsResourceName('hls/7/i2.mp4')!;
      expect((init.kind, init.index), (HlsResourceKind.init, 2));
      expect(init.contentType, 'audio/mp4');
      final key = parseHlsResourceName('hls/7/k0.key')!;
      expect((key.kind, key.index), (HlsResourceKind.key, 0));
      expect(key.contentType, 'application/octet-stream');
    });

    test('every segment ext has its content type', () {
      const types = {
        'ts': 'video/mp2t',
        'aac': 'audio/aac',
        'mp3': 'audio/mpeg',
        'm4s': 'audio/mp4',
        'ac3': 'audio/ac3',
        'ec3': 'audio/eac3',
      };
      types.forEach((ext, type) {
        expect(parseHlsResourceName('hls/1/s1.$ext')!.contentType, type);
      });
    });

    test('any other shape is null', () {
      for (final name in [
        '',
        'hls',
        'hls/1',
        'hls/1/',
        'hls/0/s0.ts', // rev is positive
        'hls/01/s0.ts', // leading zero
        'hls/1/s00.ts',
        'hls/1/s-1.ts',
        'hls/1234567890123456/s0.ts', // 16 digits
        'hls/1/s1234567890.ts', // 10 digits
        'hls/1/s0.mp4', // ext not allowed for a segment
        'hls/1/s0.key',
        'hls/1/s0',
        'hls/1/i0.ts',
        'hls/1/k0.mp4',
        'hls/1/x0.ts',
        'hls/1/s0.TS',
        'hls/1/s0.ts/extra',
        '/hls/1/s0.ts',
        'hls/1/s0.ts?x=1',
        'hls/1/../s0.ts',
      ]) {
        expect(parseHlsResourceName(name), isNull, reason: name);
      }
    });

    test('the largest numbers still parse', () {
      expect(
        parseHlsResourceName('hls/999999999999999/s999999999.ts'),
        isNotNull,
      );
    });
  });
}
