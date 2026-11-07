import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/hls/hls_refusal.dart';
import 'package:kanaru/core/sources/proxy/hls/hls_resolve_failure.dart';
import 'package:kanaru/core/sources/proxy/stream_proxy_server.dart';
import 'package:kanaru/core/sources/proxy/stream_refusal.dart';
import 'package:kanaru/core/sources/proxy/stream_resolver.dart';
import 'package:kanaru/core/sources/remote_source_ref.dart';
import 'package:kanaru/core/sources/source_models.dart';
import 'package:logging/logging.dart';

import 'hls/hls_loader_test_support.dart';
import 'proxy_test_support.dart';

/// Stands in for `stream.js`: item `prog` is a progressive file, every other
/// item an HLS playlist at [playlist]. Counts its runs.
class _Resolver implements TrackStreamResolver {
  _Resolver(this.upstream);

  final FakeUpstream upstream;
  final calls = <bool>[];
  String playlist = '/pl.m3u8';
  bool allowed = true;
  Object? error;
  Completer<void>? gate;

  @override
  String? ownerOf(String key) {
    final slash = key.indexOf('/');
    return slash <= 0 ? null : key.substring(0, slash);
  }

  @override
  Future<ResolvedStream> resolve(
    String key, {
    required bool fresh,
    required bool Function() abandoned,
  }) async {
    calls.add(fresh);
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    final progressive = key.endsWith('/prog');
    return ResolvedStream(
      url: upstream.url(progressive ? '/file' : playlist),
      headers: const {'x-plugin': 'yes'},
      mimeType: progressive ? 'audio/webm' : 'application/vnd.apple.mpegurl',
      format: progressive
          ? RemoteStreamFormat.progressive
          : RemoteStreamFormat.hls,
      allowed: () => allowed,
      redirectAllowed: declaredHost,
    );
  }
}

void main() {
  late FakeUpstream upstream;
  late _Resolver resolver;
  late StreamProxyServer proxy;
  late List<String> dropped;
  final seg = testBytes(1000);
  const ref = RemoteSourceRef(installId: testInstallId, itemId: 'item1');

  void serve(String path, String text) {
    upstream.bodies[path] = utf8.encode(text);
    upstream.contentTypes[path] = 'application/vnd.apple.mpegurl';
  }

  setUp(() async {
    upstream = await FakeUpstream.start(testBytes(300));
    resolver = _Resolver(upstream);
    dropped = [];
    proxy = StreamProxyServer(
      resolvers: {RemoteStreamKind.sourcePlugin: resolver},
      client: HttpClient()..autoUncompress = false,
      onDrop: dropped.add,
    );
    addTearDown(() async {
      await proxy.close();
      await upstream.close();
    });
    serve('/pl.m3u8', segments(2));
    upstream.bodies['/seg0.ts'] = seg;
    upstream.bodies['/seg1.ts'] = testBytes(10);
  });

  Future<Uri> urlFor([RemoteSourceRef item = ref]) async =>
      Uri.parse(await proxy.urlFor(item));

  /// [entry] with [suffix] appended to its path.
  Uri sub(Uri entry, String suffix) =>
      entry.replace(path: '${entry.path}/$suffix');

  group('the entry URL of an HLS item', () {
    test('answers the proxy-written playlist; every URI is the proxy\'s '
        'and any Range is ignored', () async {
      final entry = await urlFor();
      final answer = await rawRequest(entry, range: 'bytes=5-');
      expect(answer.status, 200);
      expect(answer.headers['content-type'], 'application/vnd.apple.mpegurl');
      expect(answer.headers['content-length'], '${answer.body.length}');
      final text = utf8.decode(answer.body);
      expect(text, startsWith('#EXTM3U\n'));
      expect(text, contains('#EXT-X-ENDLIST'));
      expect(text, isNot(contains('seg0.ts')));
      final uris = [
        for (final line in text.split('\n'))
          if (line.isNotEmpty && !line.startsWith('#')) line,
      ];
      expect(uris, ['$entry/hls/1/s0.ts', '$entry/hls/1/s1.ts']);
      expect(resolver.calls, [false]);
      // The segment bodies were not touched by the playlist.
      expect(upstream.requests.map((r) => r.path), ['/pl.m3u8']);
    });

    test('a progressive item on the same server is served as before', () async {
      upstream.contentType = 'audio/webm';
      final entry = await urlFor(
        const RemoteSourceRef(installId: testInstallId, itemId: 'prog'),
      );
      final answer = await rawRequest(entry, range: 'bytes=0-');
      expect(answer.status, 206);
      expect(answer.headers['content-range'], 'bytes 0-299/300');
      expect(answer.body, testBytes(300));
    });

    test('a failed or refused resolve: 502, and the item is dead', () async {
      serve('/pl.m3u8', '#EXTM3U\n#EXTINF:4,\nseg0.ts\n');
      final entry = await urlFor();
      final answer = await rawRequest(entry);
      expect(answer.status, 502);
      expect(answer.body, isEmpty);
      expect((await rawRequest(entry)).status, 502);
      expect(resolver.calls, [false]);
    });

    test('consent withdrawn: 502', () async {
      final entry = await urlFor();
      expect((await rawRequest(entry)).status, 200);
      resolver.allowed = false;
      expect((await rawRequest(entry)).status, 502);
    });
  });

  group('a master with AES-128 and an fMP4 init section', () {
    late Uri entry;

    setUp(() async {
      serve(
        '/pl.m3u8',
        '#EXTM3U\n'
            '#EXT-X-STREAM-INF:BANDWIDTH=1000,CODECS="mp4a.40.2"\n'
            'media.m3u8\n',
      );
      serve(
        '/media.m3u8',
        '#EXTM3U\n#EXT-X-TARGETDURATION:4\n'
            '#EXT-X-KEY:METHOD=AES-128,URI="key.bin",IV=0x000102030405060708090a0b0c0d0e0f\n'
            '#EXT-X-MAP:URI="init.mp4"\n'
            '#EXTINF:4.0,\nseg0.m4s\n#EXT-X-ENDLIST\n',
      );
      upstream.bodies['/seg0.m4s'] = seg;
      upstream.bodies['/init.mp4'] = testBytes(50);
      upstream.bodies['/key.bin'] = testBytes(16);
      entry = await urlFor();
    });

    test('the playlist names the key, the init section and the segment, '
        'each served with its content type', () async {
      final text = utf8.decode((await rawRequest(entry)).body);
      expect(text, contains('URI="$entry/hls/1/k0.key"'));
      expect(text, contains('IV=0x000102030405060708090a0b0c0d0e0f'));
      expect(text, contains('#EXT-X-MAP:URI="$entry/hls/1/i0.mp4"'));
      final key = await rawRequest(sub(entry, 'hls/1/k0.key'));
      expect(key.status, 200);
      expect(key.headers['content-type'], 'application/octet-stream');
      expect(key.body, testBytes(16));
      final init = await rawRequest(sub(entry, 'hls/1/i0.mp4'));
      expect(init.headers['content-type'], 'audio/mp4');
      expect(init.body, testBytes(50));
      final segment = await rawRequest(sub(entry, 'hls/1/s0.m4s'));
      expect(segment.status, 200);
      expect(segment.headers['content-type'], 'audio/mp4');
      expect(segment.body, seg);
      expect(resolver.calls, [false]);
    });
  });

  group('sub-resource requests', () {
    test('a segment answers its bytes and a range of them', () async {
      final entry = await urlFor();
      await rawRequest(entry);
      final whole = await rawRequest(sub(entry, 'hls/1/s0.ts'));
      expect(whole.status, 200);
      expect(whole.headers['content-type'], 'video/mp2t');
      expect(whole.body, seg);
      final part = await rawRequest(
        sub(entry, 'hls/1/s0.ts'),
        range: 'bytes=10-19',
      );
      expect(part.status, 206);
      expect(part.body, seg.sublist(10, 20));
    });

    test('a request before the playlist resolves the item itself', () async {
      final entry = await urlFor();
      expect((await rawRequest(sub(entry, 'hls/1/s0.ts'))).body, seg);
      expect(resolver.calls, [false]);
    });

    test('a path of 5, 6 or 8 segments, a 5th segment other than hls, a bad '
        'rev or name: 404 with an empty body', () async {
      final entry = await urlFor();
      await rawRequest(entry);
      for (final suffix in [
        'hls',
        'hls/1',
        'hls/1/s0.ts/extra',
        'other/1/s0.ts',
        'hls/0/s0.ts',
        'hls/01/s0.ts',
        'hls/x/s0.ts',
        'hls/1/s00.ts',
        'hls/1/s0.exe',
        'hls/1/s0',
        'hls/1/k0.ts',
        'hls/1/i0.ts',
        'hls/1/s99.ts',
        'hls/1/k0.key',
        'hls/1/i0.mp4',
        'hls/7/s0.ts',
      ]) {
        final answer = await rawRequest(sub(entry, suffix));
        expect(answer.status, 404, reason: suffix);
        expect(answer.body, isEmpty, reason: suffix);
      }
      expect(resolver.calls, [false]);
    });

    test('a wrong Host or token: 404; POST: 405', () async {
      final entry = await urlFor();
      final name = sub(entry, 'hls/1/s0.ts');
      await rawRequest(entry);
      expect((await rawRequest(name, host: 'localhost')).status, 404);
      final parts = name.path.split('/')..[1] = 'x' * 43;
      final badToken = name.replace(path: parts.join('/'));
      expect((await rawRequest(badToken)).status, 404);
      expect((await rawRequest(name, method: 'POST')).status, 405);
    });

    test('an item never begun, or of another install: 404', () async {
      final entry = await urlFor();
      await rawRequest(entry);
      final parts = entry.path.split('/')..[4] = 'other';
      final other = entry.replace(path: '${parts.join('/')}/hls/1/s0.ts');
      expect((await rawRequest(other)).status, 404);
      expect(resolver.calls, [false]);
    });

    test('a dead item answers 502 at once, without stream.js', () async {
      final entry = await urlFor();
      await rawRequest(entry);
      upstream.forbidden.addAll({'/seg0.ts', '/pl.m3u8'});
      final name = sub(entry, 'hls/1/s0.ts');
      expect((await rawRequest(name)).status, 502);
      final calls = resolver.calls.length;
      expect((await rawRequest(name)).status, 502);
      expect(resolver.calls, hasLength(calls));
    });

    test(
      'a repeat of the item keeps serving its old sub-resource URLs',
      () async {
        final entry = await urlFor();
        await rawRequest(entry);
        final again = await urlFor();
        expect(again, entry);
        final segment = await rawRequest(sub(entry, 'hls/1/s0.ts'));
        expect(segment.body, seg);
        expect(resolver.calls, [false]);
      },
    );
  });

  group('drops', () {
    test('a drop ends an open segment body; later requests are 404 without '
        'stream.js; a restore serves again from the next urlFor', () async {
      upstream
        ..piece = 100
        ..pause = const Duration(milliseconds: 40);
      final entry = await urlFor();
      await rawRequest(entry);
      final open = await OpenRawRequest.send(sub(entry, 'hls/1/s0.ts'));
      await until(() => open.received.length > 300);

      proxy.dropPlugin(testInstallId);
      await open.closed.timeout(const Duration(seconds: 2));
      expect(parseRawAnswer(open.received).body.length, lessThan(1000));
      expect(dropped, [testInstallId]);

      final calls = resolver.calls.length;
      expect((await rawRequest(sub(entry, 'hls/1/s1.ts'))).status, 404);
      expect((await rawRequest(entry)).status, 404);
      expect(resolver.calls, hasLength(calls));

      upstream
        ..piece = 64 * 1024
        ..pause = Duration.zero;
      proxy.restorePlugin(testInstallId);
      final back = await urlFor();
      final playlist = await rawRequest(back);
      expect(playlist.status, 200);
      expect(utf8.decode(playlist.body), contains('/hls/2/s0.ts'));
      expect((await rawRequest(sub(back, 'hls/2/s0.ts'))).body, seg);
    });
  });

  group('formatOf', () {
    test('an HLS item: hls; a progressive one: progressive', () async {
      final hls = await urlFor();
      final file = await urlFor(
        const RemoteSourceRef(installId: testInstallId, itemId: 'prog'),
      );
      expect(await proxy.formatOf('$hls'), RemoteStreamFormat.hls);
      expect(await proxy.formatOf('$file'), RemoteStreamFormat.progressive);
    });

    test('a URL of another port or token, a forgotten item or a dropped '
        'owner: null without stream.js', () async {
      final entry = await urlFor();
      final parts = entry.path.split('/')..[1] = 'x' * 43;
      expect(
        await proxy.formatOf('${entry.replace(port: entry.port + 1)}'),
        isNull,
      );
      expect(
        await proxy.formatOf('${entry.replace(path: parts.join('/'))}'),
        isNull,
      );
      final forgotten = entry.replace(path: '${entry.path}2');
      expect(await proxy.formatOf('$forgotten'), isNull);
      expect(await proxy.formatOf('${sub(entry, 'hls/1/s0.ts')}'), isNull);
      expect(await proxy.formatOf('not a url'), isNull);
      expect(await proxy.formatOf(''), isNull);
      proxy.dropPlugin(testInstallId);
      expect(await proxy.formatOf('$entry'), isNull);
      expect(resolver.calls, isEmpty);
    });

    test('a failed resolve: null', () async {
      resolver.error = const ResolveFailure('unavailable');
      expect(await proxy.formatOf('${await urlFor()}'), isNull);
    });

    test('called while a request already waits on the resolve: one stream.js '
        'run', () async {
      final entry = await urlFor();
      resolver.gate = Completer<void>();
      final request = rawRequest(entry);
      await until(() => resolver.calls.isNotEmpty);
      final format = proxy.formatOf('$entry');
      resolver.gate!.complete();
      expect(await format, RemoteStreamFormat.hls);
      expect((await request).status, 200);
      expect(resolver.calls, [false]);
    });

    test('a resolve that outlasts the format deadline: null', () async {
      final quick = StreamProxyServer(
        resolvers: {RemoteStreamKind.sourcePlugin: resolver},
        client: HttpClient()..autoUncompress = false,
        onDrop: (_) {},
        formatDeadline: const Duration(milliseconds: 1),
      );
      addTearDown(quick.close);
      final entry = Uri.parse(await quick.urlFor(ref));
      resolver.gate = Completer<void>();
      final clock = Stopwatch()..start();
      expect(await quick.formatOf('$entry'), isNull);
      expect(clock.elapsed, lessThan(const Duration(seconds: 5)));
      resolver.gate!.complete();
      expect(resolver.calls, [false]);
    });

    test('before any urlFor: null', () async {
      expect(await proxy.formatOf('http://127.0.0.1:1/x/y/z/w'), isNull);
    });
  });

  group('what the user sees', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [sourceStreamProxyProvider.overrideWithValue(proxy)],
      );
      addTearDown(container.dispose);
    });

    StreamRefusal? refusal() =>
        container.read(remoteStreamRefusalProvider)(ref);

    test('a live playlist is live, a protected one protected', () async {
      serve('/pl.m3u8', '#EXTM3U\n#EXTINF:4,\nseg0.ts\n');
      expect((await rawRequest(await urlFor())).status, 502);
      expect(refusal(), StreamRefusal.live);

      serve(
        '/pl.m3u8',
        '#EXTM3U\n#EXT-X-KEY:METHOD=SAMPLE-AES,URI="k"\n#EXTINF:4,\n'
            'seg0.ts\n#EXT-X-ENDLIST\n',
      );
      expect((await rawRequest(await urlFor())).status, 502);
      expect(refusal(), StreamRefusal.protected);
    });

    test('other failures, a good item and an unknown item: null', () async {
      resolver.error = HlsResolveFailure(HlsRefusalKind.invalid);
      expect((await rawRequest(await urlFor())).status, 502);
      expect(refusal(), isNull);
      expect(
        container.read(remoteStreamRefusalProvider)(
          const RemoteSourceRef(installId: testInstallId, itemId: 'nope'),
        ),
        isNull,
      );
      resolver.error = null;
      expect((await rawRequest(await urlFor())).status, 200);
      expect(refusal(), isNull);
    });

    test('a proxy that cannot be read: null', () {
      final broken = ProviderContainer(
        overrides: [
          sourceStreamProxyProvider.overrideWith(
            (ref) => throw StateError('x'),
          ),
        ],
      );
      addTearDown(broken.dispose);
      expect(broken.read(remoteStreamRefusalProvider)(ref), isNull);
    });
  });

  group('the log of a refused playlist', () {
    late List<String> records;

    setUp(() {
      records = [];
      final level = Logger.root.level;
      Logger.root.level = Level.ALL;
      final logs = Logger.root.onRecord.listen((r) => records.add(r.message));
      addTearDown(() async {
        await logs.cancel();
        Logger.root.level = level;
      });
    });

    test('a live playlist logs one line with one prefix', () async {
      serve('/pl.m3u8', '#EXTM3U\n#EXTINF:4,\nseg0.ts\n');
      expect((await rawRequest(await urlFor())).status, 502);
      expect(records.where((l) => l.contains('resolve failed')), [
        '$testInstallId resolve failed: hls live',
      ]);
    });

    test('consent withdrawn before the playlist answer: 502 and one '
        'line', () async {
      final entry = await urlFor();
      expect((await rawRequest(entry)).status, 200);
      records.clear();
      resolver.allowed = false;
      expect((await rawRequest(entry)).status, 502);
      expect(records.where((l) => l.startsWith(testInstallId)), [
        '$testInstallId hls playlist 502: consent withdrawn',
      ]);
    });
  });

  test('the log never holds the token, a URL or a query', () async {
    final records = <String>[];
    final level = Logger.root.level;
    Logger.root.level = Level.ALL;
    final logs = Logger.root.onRecord.listen((r) => records.add(r.message));
    addTearDown(() async {
      await logs.cancel();
      Logger.root.level = level;
    });
    final entry = await urlFor();
    await rawRequest(entry);
    await rawRequest(sub(entry, 'hls/1/s0.ts'));
    await rawRequest(sub(entry, 'hls/1/s99.ts'));
    upstream.forbidden.addAll({'/seg1.ts', '/pl.m3u8'});
    await rawRequest(sub(entry, 'hls/1/s1.ts'));
    serve('/pl.m3u8', '#EXTM3U\n#EXTINF:4,\nseg0.ts\n');
    upstream.forbidden.clear();
    await rawRequest(
      await urlFor(
        const RemoteSourceRef(installId: testInstallId, itemId: 'live'),
      ),
    );
    proxy.dropPlugin(testInstallId);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(records, isNotEmpty);
    final token = entry.pathSegments.first;
    for (final message in records) {
      expect(message, isNot(contains(token)));
      expect(message, isNot(contains('127.0.0.1')));
      expect(message, isNot(contains('/seg')));
      expect(message, isNot(contains('.m3u8')));
    }
  });
}
