import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/proxy/range_request.dart';
import 'package:kanaru/core/sources/proxy/resolved_streams.dart';
import 'package:kanaru/core/sources/proxy/upstream_reader.dart';

import 'proxy_test_support.dart';

void main() {
  late FakeUpstream upstream;
  late CountingResolver resolver;
  late ResolvedStreams streams;
  late HttpClient client;
  late UpstreamReader reader;
  final bytes = testBytes(2500);

  setUp(() async {
    upstream = await FakeUpstream.start(bytes);
    resolver = CountingResolver(upstream);
    streams = ResolvedStreams(resolver.resolve);
    // Plain loopback client: the URL rules and the public-only connector are
    // the resolver's and the app client's, tested on their own.
    client = HttpClient()..autoUncompress = false;
    reader = UpstreamReader(client, chunkBytes: 1000);
    addTearDown(() async {
      client.close(force: true);
      await upstream.close();
    });
  });

  Playthrough begin() => streams.begin('$testInstallId/x', testInstallId);

  Future<ProxyAnswer> open([String? range, Playthrough? playthrough]) =>
      reader.open(playthrough ?? begin(), RangeRequest.parse(range));

  Future<List<int>> body(ProxyAnswer answer) async {
    final out = <int>[];
    await answer.body?.forEach(out.addAll);
    return out;
  }

  test(
    'no range: 200 with the whole body, fetched in bounded chunks',
    () async {
      final answer = await open();
      expect(answer.status, 200);
      expect(answer.headers['content-length'], '2500');
      expect(answer.headers['accept-ranges'], 'bytes');
      expect(answer.headers.containsKey('content-range'), isFalse);
      expect(answer.headers['content-type'], 'audio/webm');
      expect(await body(answer), bytes);
      expect(await answer.done, 2500);
      expect(upstream.ranges, [
        'bytes=0-999',
        'bytes=1000-1999',
        'bytes=2000-2499',
      ]);
    },
  );

  test('every upstream request sends identity, the plugin headers and a '
      'closed range', () async {
    await body(await open('bytes=0-'));
    for (final request in upstream.requests) {
      expect(request.headers.value('accept-encoding'), 'identity');
      expect(request.headers.value('x-plugin'), 'yes');
      expect(request.headers.value('user-agent'), 'PluginAgent');
      expect(request.range, matches(RegExp(r'^bytes=\d+-\d+$')));
    }
    expect(upstream.requests, hasLength(3));
  });

  test('an open range: 206 from that byte to the end', () async {
    final answer = await open('bytes=512-');
    expect(answer.status, 206);
    expect(answer.headers['content-range'], 'bytes 512-2499/2500');
    expect(answer.headers['content-length'], '1988');
    expect(await body(answer), bytes.sublist(512));
    expect(upstream.ranges, ['bytes=512-1511', 'bytes=1512-2499']);
  });

  test('a closed range inside one chunk: one upstream request', () async {
    final answer = await open('bytes=10-19');
    expect(answer.status, 206);
    expect(answer.headers['content-range'], 'bytes 10-19/2500');
    expect(await body(answer), bytes.sublist(10, 20));
    expect(upstream.ranges, ['bytes=10-19']);
  });

  test('a closed range past the end is cut to the body', () async {
    final answer = await open('bytes=2400-9000');
    expect(answer.headers['content-range'], 'bytes 2400-2499/2500');
    expect(await body(answer), bytes.sublist(2400));
  });

  test('a suffix range: the size is probed, then the tail is sent', () async {
    final answer = await open('bytes=-250');
    expect(answer.status, 206);
    expect(answer.headers['content-range'], 'bytes 2250-2499/2500');
    expect(await body(answer), bytes.sublist(2250));
    expect(upstream.ranges, ['bytes=0-0', 'bytes=2250-2499']);
  });

  test('a range past the end: 416 with the size', () async {
    final answer = await open('bytes=2500-');
    expect(answer.status, 416);
    expect(answer.headers['content-range'], 'bytes */2500');
    expect(answer.body, isNull);
  });

  test('several ranges: 416 without asking upstream', () async {
    final answer = await open('bytes=0-1,4-5');
    expect(answer.status, 416);
    expect(resolver.calls, isEmpty);
    expect(upstream.requests, isEmpty);
  });

  test(
    '403 on the first request: one fresh resolve, then playback goes on',
    () async {
      upstream.forbidden.add('/s1');
      final answer = await open('bytes=0-');
      expect(answer.status, 206);
      expect(await body(answer), bytes);
      expect(resolver.calls, [false, true]);
    },
  );

  test(
    '403 in the middle of a body: the fresh stream serves the same chunk',
    () async {
      upstream.forbiddenAfter['/s1'] = 1;
      final answer = await open('bytes=0-');
      expect(await body(answer), bytes);
      expect(resolver.calls, [false, true]);
      expect(
        [for (final r in upstream.requests) '${r.path} ${r.range}'],
        [
          '/s1 bytes=0-999',
          '/s1 bytes=1000-1999',
          '/s2 bytes=1000-1999',
          '/s2 bytes=2000-2499',
        ],
      );
    },
  );

  test('a second 403 answers 502; five reconnects after it answer 502 with '
      'exactly two stream.js calls in total', () async {
    upstream.forbidden.addAll({'/s1', '/s2'});
    final playthrough = begin();
    final first = await open('bytes=0-', playthrough);
    expect(first.status, 502);
    for (var i = 0; i < 5; i++) {
      final again = await open('bytes=0-', playthrough);
      expect(again.status, 502);
    }
    expect(resolver.calls, [false, true]);
    expect(upstream.requests, hasLength(2));
  });

  test('a second 403 after the headers ends the body', () async {
    upstream
      ..forbiddenAfter['/s1'] = 1
      ..forbidden.add('/s2');
    final answer = await open('bytes=0-');
    expect(answer.status, 206);
    expect(await body(answer), bytes.sublist(0, 1000));
    expect(resolver.calls, [false, true]);
  });

  test('a redirect answers 502 and is not followed', () async {
    upstream.redirected.add('/s1');
    final answer = await open('bytes=0-');
    expect(answer.status, 502);
    expect([for (final r in upstream.requests) r.path], ['/s1']);
  });

  test(
    'an answer with neither Content-Range nor Content-Length: 502',
    () async {
      upstream.omitLengths = true;
      final answer = await open('bytes=0-');
      expect(answer.status, 502);
    },
  );

  test('a failed resolve answers 502', () async {
    resolver.failing = true;
    expect((await open('bytes=0-')).status, 502);
  });

  test('without consent nothing is fetched: 502', () async {
    resolver.allowed = false;
    expect((await open('bytes=0-')).status, 502);
    expect(upstream.requests, isEmpty);
  });

  test(
    'consent withdrawn while playing: the body stops at the next chunk',
    () async {
      upstream
        ..piece = 500
        ..pause = const Duration(milliseconds: 30);
      final answer = await open('bytes=0-');
      final got = <int>[];
      await answer.body!.forEach((data) {
        got.addAll(data);
        resolver.allowed = false;
      });
      expect(got, bytes.sublist(0, 1000));
      expect(upstream.requests, hasLength(1));
    },
  );

  test(
    'an upstream that ignores Range serves a body from byte 0 only',
    () async {
      upstream.ignoreRange = true;
      final whole = await open('bytes=0-');
      expect(whole.status, 206);
      expect(await body(whole), bytes);
      expect(upstream.requests, hasLength(1));

      expect((await open('bytes=512-')).status, 502);
    },
  );

  test('the client leaving cancels the upstream answer', () async {
    reader = UpstreamReader(client, chunkBytes: 1 << 20);
    final big = testBytes(1 << 20);
    await upstream.close();
    upstream = await FakeUpstream.start(big);
    upstream
      ..piece = 1000
      ..pause = const Duration(milliseconds: 5);
    resolver = CountingResolver(upstream);
    streams = ResolvedStreams(resolver.resolve);
    final answer = await open('bytes=0-');
    final cut = upstream.cuts.first;
    final first = Completer<void>();
    final sub = answer.body!.listen((_) {
      if (!first.isCompleted) first.complete();
    });
    await first.future;
    await sub.cancel();
    await cut.timeout(const Duration(seconds: 5));
    expect(upstream.cutShort, 1);
    expect(await answer.done, lessThan(big.length));
  });

  group('content-type', () {
    test('the plugin type when it is a media type', () async {
      resolver.mimeType = 'audio/mp4; codecs="mp4a.40.2"';
      upstream.contentType = 'application/octet-stream';
      final answer = await open('bytes=0-9');
      expect(answer.headers['content-type'], 'audio/mp4; codecs="mp4a.40.2"');
    });

    test(
      'a plugin type with a header break falls back to the upstream one',
      () async {
        resolver.mimeType = 'audio/webm\r\nx-evil: 1';
        upstream.contentType = 'audio/ogg';
        final answer = await open('bytes=0-9');
        expect(answer.headers['content-type'], 'audio/ogg');
        expect(answer.headers.containsKey('x-evil'), isFalse);
      },
    );

    test('none when neither is a media type', () async {
      resolver.mimeType = 'webm';
      upstream.contentType = 'not a type';
      final answer = await open('bytes=0-9');
      expect(answer.headers.containsKey('content-type'), isFalse);
    });
  });
}
