import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/proxy/hls/hls_resource_reader.dart';
import 'package:kanaru/core/sources/source_models.dart';

import '../proxy_test_support.dart';
import 'hls_loader_test_support.dart';
import 'hls_reader_test_support.dart';

/// A media playlist of 4 s segments from [lines] (the tags and URIs).
String playlistOf(List<String> lines) => [
  '#EXTM3U',
  '#EXT-X-TARGETDURATION:4',
  ...lines,
  '#EXT-X-ENDLIST',
].join('\n');

void main() {
  late ReaderRig rig;
  final seg = testBytes(1000);

  Future<ReaderRig> start({int segmentLimit = hlsMaxSegmentBytes}) async {
    rig = await ReaderRig.start(segmentLimit: segmentLimit);
    rig.loader.serve('/p1.m3u8', segments(2));
    rig.serveBytes('/seg0.ts', seg);
    rig.serveBytes('/seg1.ts', testBytes(10));
    return rig;
  }

  setUp(() => start());
  tearDown(() => rig.close());

  group('segments', () {
    test('no range: 200 with the whole segment and its content type', () async {
      final answer = await rig.open('hls/1/s0.ts');
      expect(answer.status, 200);
      expect(answer.headers['content-length'], '1000');
      expect(answer.headers['content-type'], 'video/mp2t');
      expect(answer.headers['accept-ranges'], 'bytes');
      expect(answer.headers.containsKey('content-range'), isFalse);
      expect(await bodyOf(answer), seg);
      expect(await answer.done, 1000);
    });

    test('the request carries the plugin headers, identity and no range '
        'for a whole segment', () async {
      await bodyOf(await rig.open('hls/1/s0.ts'));
      final request = rig.upstream.requests.last;
      expect(request.path, '/seg0.ts');
      expect(request.range, isNull);
      expect(request.headers.value('accept-encoding'), 'identity');
      expect(request.headers.value('x-plugin'), 'yes');
    });

    test('the ext of the name sets the content type', () async {
      final answer = await rig.open('hls/1/s0.aac');
      expect(answer.headers['content-type'], 'audio/aac');
      await bodyOf(answer);
    });

    test('an empty segment: 200 with length 0', () async {
      rig.serveBytes('/seg0.ts', const []);
      final answer = await rig.open('hls/1/s0.ts');
      expect(answer.status, 200);
      expect(answer.headers['content-length'], '0');
      expect(answer.body, isNull);
    });
  });

  group('Range', () {
    // Pieces smaller than the dropped prefix.
    setUp(() => rig.upstream.piece = 300);

    Future<void> expectServed(
      String? range, {
      required int status,
      required int from,
      required int to,
      String? contentRange,
    }) async {
      final answer = await rig.open('hls/1/s0.ts', range);
      expect(answer.status, status, reason: '$range');
      expect(answer.headers['content-range'], contentRange);
      expect(answer.headers['content-length'], '${to - from}');
      expect(await bodyOf(answer), seg.sublist(from, to), reason: '$range');
      expect(await answer.done, to - from);
      // The upstream is always read from the start, without a range.
      expect(rig.upstream.requests.last.range, isNull);
    }

    test('none: the whole segment, 200', () {
      return expectServed(null, status: 200, from: 0, to: 1000);
    });

    test('bytes=0-: the whole segment, 206 with content-range', () {
      return expectServed(
        'bytes=0-',
        status: 206,
        from: 0,
        to: 1000,
        contentRange: 'bytes 0-999/1000',
      );
    });

    test('bytes=450-: the bytes before it are dropped', () {
      return expectServed(
        'bytes=450-',
        status: 206,
        from: 450,
        to: 1000,
        contentRange: 'bytes 450-999/1000',
      );
    });

    test('bytes=10-19 and bytes=-10', () async {
      await expectServed(
        'bytes=10-19',
        status: 206,
        from: 10,
        to: 20,
        contentRange: 'bytes 10-19/1000',
      );
      await expectServed(
        'bytes=-10',
        status: 206,
        from: 990,
        to: 1000,
        contentRange: 'bytes 990-999/1000',
      );
    });

    test('past the end: 416 with the size', () async {
      final answer = await rig.open('hls/1/s0.ts', 'bytes=5000-');
      expect(answer.status, 416);
      expect(answer.headers['content-range'], 'bytes */1000');
      expect(answer.body, isNull);
    });

    test('several ranges or a bad range: 416, nothing fetched', () async {
      for (final range in ['bytes=0-1,5-6', 'bytes=x-', 'items=0-1']) {
        final answer = await rig.open('hls/1/s0.ts', range);
        expect(answer.status, 416, reason: range);
      }
      expect(rig.paths, isEmpty);
    });
  });

  group('init sections and keys', () {
    setUp(() async {
      rig.loader.serve(
        '/p1.m3u8',
        playlistOf([
          '#EXT-X-MAP:URI="init.mp4"',
          '#EXT-X-KEY:METHOD=AES-128,URI="key.bin"',
          '#EXTINF:4.0,',
          'seg0.m4s',
        ]),
      );
      rig.serveBytes('/init.mp4', testBytes(300));
      rig.serveBytes('/key.bin', testBytes(16));
    });

    test('an init section: audio/mp4, the whole body', () async {
      final answer = await rig.open('hls/1/i0.mp4');
      expect(answer.status, 200);
      expect(answer.headers['content-type'], 'audio/mp4');
      expect(await bodyOf(answer), testBytes(300));
    });

    test('a key: 16 bytes, octet-stream', () async {
      final answer = await rig.open('hls/1/k0.key');
      expect(answer.status, 200);
      expect(answer.headers['content-type'], 'application/octet-stream');
      expect(answer.headers['content-length'], '16');
      expect(await bodyOf(answer), testBytes(16));
    });

    test('a key answers a range too', () async {
      final answer = await rig.open('hls/1/k0.key', 'bytes=4-7');
      expect(answer.status, 206);
      expect(answer.headers['content-range'], 'bytes 4-7/16');
      expect(await bodyOf(answer), testBytes(16).sublist(4, 8));
    });

    test('a key one byte short or long is 502, with no body', () async {
      for (final length in [15, 17, 0, 100000]) {
        rig.serveBytes('/key.bin', testBytes(length));
        final answer = await rig.open('hls/1/k0.key');
        expect(answer.status, 502, reason: '$length bytes');
        expect(answer.body, isNull);
      }
    });

    test('an init section over its bound is 502', () async {
      await rig.close();
      rig = await ReaderRig.start(initLimit: 100);
      rig.loader.serve(
        '/p1.m3u8',
        playlistOf(['#EXT-X-MAP:URI="init.mp4"', '#EXTINF:4.0,', 'seg0.m4s']),
      );
      rig.serveBytes('/init.mp4', testBytes(101));
      expect((await rig.open('hls/1/i0.mp4')).status, 502);
      rig.serveBytes('/init.mp4', testBytes(100));
      expect((await rig.open('hls/1/i0.mp4')).status, 200);
    });
  });

  group('byte-range segments', () {
    setUp(() {
      rig.loader.serve(
        '/p1.m3u8',
        playlistOf(['#EXTINF:4.0,', '#EXT-X-BYTERANGE:100@200', 'one.ts']),
      );
      rig.serveBytes('/one.ts', seg);
    });

    test('asks a closed range and serves the 206 body', () async {
      final answer = await rig.open('hls/1/s0.ts');
      expect(answer.status, 200);
      expect(answer.headers['content-length'], '100');
      expect(await bodyOf(answer), seg.sublist(200, 300));
      expect(rig.upstream.requests.last.range, 'bytes=200-299');
    });

    test('a client range inside the byte range', () async {
      final answer = await rig.open('hls/1/s0.ts', 'bytes=10-19');
      expect(answer.status, 206);
      expect(answer.headers['content-range'], 'bytes 10-19/100');
      expect(await bodyOf(answer), seg.sublist(210, 220));
    });

    test('upstream ignoring the range (200) is 502', () async {
      rig.upstream.ignoreRange = true;
      final answer = await rig.open('hls/1/s0.ts');
      expect(answer.status, 502);
      expect(answer.body, isNull);
    });

    test('a 206 without content-range is 502', () async {
      rig.upstream.omitLengths = true;
      expect((await rig.open('hls/1/s0.ts')).status, 502);
    });

    test(
      'a range longer than the segment bound is 502, nothing sent',
      () async {
        await rig.close();
        await start(segmentLimit: 99);
        rig.loader.serve(
          '/p1.m3u8',
          playlistOf(['#EXTINF:4.0,', '#EXT-X-BYTERANGE:100@200', 'one.ts']),
        );
        expect((await rig.open('hls/1/s0.ts')).status, 502);
        expect(rig.paths, ['/p1.m3u8']);
      },
    );
  });

  group('segment bounds', () {
    setUp(() async {
      await rig.close();
      await start(segmentLimit: 400);
    });

    test('a length above the bound is 502 before any byte', () async {
      final answer = await rig.open('hls/1/s0.ts');
      expect(answer.status, 502);
      expect(answer.body, isNull);
    });

    test('the bound itself is served', () async {
      rig.serveBytes('/seg0.ts', testBytes(400));
      final answer = await rig.open('hls/1/s0.ts');
      expect(answer.status, 200);
      expect(await bodyOf(answer), testBytes(400));
    });

    group('without a Content-Length', () {
      setUp(() async {
        // The playlist is loaded before the lengths go.
        await rig.playthrough.current();
        rig.upstream.omitLengths = true;
      });

      test('served 200 without a length, cut at the bound', () async {
        final answer = await rig.open('hls/1/s0.ts');
        expect(answer.status, 200);
        expect(answer.headers.containsKey('content-length'), isFalse);
        expect(await bodyOf(answer), seg.sublist(0, 400));
      });

      test('a shorter body is served whole', () async {
        final answer = await rig.open('hls/1/s1.ts');
        expect(answer.status, 200);
        expect(await bodyOf(answer), testBytes(10));
      });

      test('bytes=0- is the whole body, 200', () async {
        final answer = await rig.open('hls/1/s1.ts', 'bytes=0-');
        expect(answer.status, 200);
        expect(await bodyOf(answer), testBytes(10));
      });

      test('a range starting later, or a suffix, is 502', () async {
        expect((await rig.open('hls/1/s1.ts', 'bytes=5-')).status, 502);
        expect((await rig.open('hls/1/s1.ts', 'bytes=-5')).status, 502);
      });
    });
  });

  group('what is not served', () {
    test('a rev nobody handed out is 404, nothing fetched', () async {
      await rig.playthrough.current();
      final answer = await rig.open('hls/99/s0.ts');
      expect(answer.status, 404);
      expect(rig.paths, ['/p1.m3u8']);
    });

    test('a rev of another item is 404', () async {
      await rig.playthrough.current();
      final snapshot = (await rig.playthrough.current()).hls!;
      final other = rig.loader.loader.memory.remember('other', snapshot.layout);
      expect((await rig.open('hls/$other/s0.ts')).status, 404);
    });

    test('an index past the snapshot, an init or key it lacks: 404', () async {
      for (final name in [
        'hls/1/s2.ts',
        'hls/1/s99.ts',
        'hls/1/i0.mp4',
        'hls/1/k0.key',
      ]) {
        expect((await rig.open(name)).status, 404, reason: name);
      }
      expect(rig.paths, ['/p1.m3u8']);
    });

    test('a progressive item has no HLS resources: 404', () async {
      await rig.close();
      rig = await ReaderRig.start(format: RemoteStreamFormat.progressive);
      expect((await rig.open('hls/1/s0.ts')).status, 404);
      expect(rig.paths, isEmpty);
    });

    test('upstream 404 is 502 for that request only', () async {
      rig.upstream.statuses['/seg1.ts'] = 404;
      expect((await rig.open('hls/1/s1.ts')).status, 502);
      expect((await rig.open('hls/1/s0.ts')).status, 200);
      expect(rig.playthrough.dead, isFalse);
    });

    test('upstream 500 on a key is 502', () async {
      rig.loader.serve(
        '/p1.m3u8',
        playlistOf([
          '#EXT-X-KEY:METHOD=AES-128,URI="key.bin"',
          '#EXTINF:4.0,',
          'seg0.ts',
        ]),
      );
      rig.upstream.statuses['/key.bin'] = 500;
      expect((await rig.open('hls/1/k0.key')).status, 502);
    });
  });
}
