import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:kanaru/core/sources/proxy/resolved_streams.dart';
import 'package:kanaru/core/sources/proxy/stream_proxy_server.dart';
import 'package:kanaru/core/sources/proxy/stream_resolver.dart';
import 'package:kanaru/core/sources/remote_source_ref.dart';

import 'proxy_test_support.dart';

/// Fails a resolve the proxy abandoned while it ran, as the source plugin
/// resolver does (`skipped`).
class _AbandoningResolver extends CountingResolver {
  _AbandoningResolver(super.upstream);

  @override
  Future<ResolvedStream> resolve(
    String key, {
    required bool fresh,
    required bool Function() abandoned,
  }) async {
    final stream = await super.resolve(key, fresh: fresh, abandoned: abandoned);
    if (abandoned()) throw const ResolveFailure('skipped');
    return stream;
  }
}

void main() {
  late FakeUpstream upstream;
  late CountingResolver resolver;
  late HttpClient client;
  late StreamProxyServer proxy;
  late List<String> dropped;
  final bytes = testBytes(2500);
  const ref = RemoteSourceRef(installId: testInstallId, itemId: 'a/b ü%');

  setUp(() async {
    upstream = await FakeUpstream.start(bytes);
    resolver = _AbandoningResolver(upstream);
    dropped = [];
    client = HttpClient()..autoUncompress = false;
    proxy = StreamProxyServer(
      resolvers: {RemoteStreamKind.sourcePlugin: resolver},
      client: client,
      onDrop: dropped.add,
      chunkBytes: 1000,
    );
    addTearDown(() async {
      await proxy.close();
      await upstream.close();
    });
  });

  Future<Uri> urlFor([RemoteSourceRef item = ref]) async =>
      Uri.parse(await proxy.urlFor(item));

  /// [url] with path segment [index] replaced by [value] (already encoded).
  Uri withSegment(Uri url, int index, String value) {
    final parts = url.path.split('/')..[index + 1] = value;
    return url.replace(path: parts.join('/'));
  }

  test('the proxy URL has the loopback address, a 32-byte token, the kind '
      'and the encoded key', () async {
    final url = await urlFor();
    expect(
      url.toString(),
      matches(
        RegExp(
          r'^http://127\.0\.0\.1:\d+/[A-Za-z0-9_-]{43}/source-plugin/'
          r'plugin-abc123def456/a%2Fb%20%C3%BC%25$',
        ),
      ),
    );
  });

  test('two urlFor calls before the first bind ends bind once', () async {
    final both = await Future.wait([proxy.urlFor(ref), proxy.urlFor(ref)]);
    final a = Uri.parse(both[0]);
    final b = Uri.parse(both[1]);
    expect(a.port, b.port);
    expect(a.pathSegments.first, b.pathSegments.first);
    expect(Uri.parse(await proxy.urlFor(ref)).port, a.port);
  });

  test('206: range headers, the plugin type and the bytes; the key is the '
      'decoded item id', () async {
    final answer = await rawRequest(await urlFor(), range: 'bytes=0-');
    expect(answer.status, 206);
    expect(answer.headers['content-range'], 'bytes 0-2499/2500');
    expect(answer.headers['content-length'], '2500');
    expect(answer.headers['accept-ranges'], 'bytes');
    expect(answer.headers['content-type'], 'audio/webm');
    expect(answer.body, bytes);
    expect(resolver.keys, ['$testInstallId/a/b ü%']);
  });

  test('200 with the whole body when no Range is sent', () async {
    final answer = await rawRequest(await urlFor());
    expect(answer.status, 200);
    expect(answer.headers['content-length'], '2500');
    expect(answer.headers.containsKey('content-range'), isFalse);
    expect(answer.body, bytes);
  });

  test('a plugin type with a non-ASCII character: the answer is still '
      'written, with the upstream type', () async {
    resolver.mimeType = 'audio/webm; codecs="opus é"';
    upstream.contentType = 'audio/ogg';
    final answer = await rawRequest(
      await urlFor(),
      range: 'bytes=0-',
    ).timeout(const Duration(seconds: 5));
    expect(answer.status, 206);
    expect(answer.headers['content-type'], 'audio/ogg');
    expect(answer.body, bytes);
  });

  test('requests of one playthrough share one resolve', () async {
    final url = await urlFor();
    await rawRequest(url, range: 'bytes=0-');
    await rawRequest(url, range: 'bytes=2250-');
    await rawRequest(url, range: 'bytes=512-');
    expect(resolver.calls, [false]);
  });

  test('the same item begun again while its first request waits on the '
      'resolve: that request is answered and stream.js ran once', () async {
    resolver.gate = Completer<void>();
    final url = await urlFor();
    final waiting = rawRequest(url, range: 'bytes=0-');
    await until(() => resolver.calls.isNotEmpty);

    // Repeat all on a one-track queue opens the item and queues it again.
    expect(await urlFor(), url);
    resolver.gate!.complete();

    final answer = await waiting.timeout(const Duration(seconds: 5));
    expect(answer.status, 206);
    expect(answer.body, bytes);
    expect(resolver.calls, [false]);
    expect((await rawRequest(url, range: 'bytes=2000-')).status, 206);
    expect(resolver.calls, [false]);
  });

  test('only the last 16 items begun are served; an item whose body is '
      'being sent is kept past them', () async {
    upstream
      ..piece = 100
      ..pause = const Duration(milliseconds: 40);
    const gone = RemoteSourceRef(installId: testInstallId, itemId: 'gone');
    final goneUrl = await urlFor(gone);
    final url = await urlFor();
    final open = await OpenRawRequest.send(url, range: 'bytes=0-');
    addTearDown(open.destroy);
    await until(() => open.received.length > 300);

    // A supersede of the item hands its open body on.
    await urlFor();
    for (var i = 0; i <= maxPlaythroughKeys; i++) {
      await urlFor(RemoteSourceRef(installId: testInstallId, itemId: 'o$i'));
    }

    final calls = resolver.calls.length;
    final forgotten = await rawRequest(goneUrl, range: 'bytes=0-');
    expect(forgotten.status, 404);
    expect(forgotten.body, isEmpty);
    expect(resolver.calls, hasLength(calls));

    upstream.pause = Duration.zero;
    final kept = await rawRequest(url, range: 'bytes=2000-');
    expect(kept.status, 206);
    expect(kept.body, bytes.sublist(2000));

    // Begun again later, the forgotten item has a new playthrough.
    final again = await rawRequest(await urlFor(gone), range: 'bytes=0-');
    expect(again.status, 206);
    expect(resolver.keys.last, '$testInstallId/gone');
    expect(resolver.calls, hasLength(calls + 1));
  });

  test('a Host other than 127.0.0.1:<port> is refused with 404', () async {
    final url = await urlFor();
    for (final host in [
      'localhost:${url.port}',
      '127.0.0.1',
      '127.0.0.1:${url.port + 1}',
      'evil.example.com',
    ]) {
      final answer = await rawRequest(url, host: host);
      expect(answer.status, 404, reason: host);
      expect(answer.body, isEmpty, reason: host);
    }
    expect(resolver.calls, isEmpty);
  });

  test('a method other than GET: 405', () async {
    final url = await urlFor();
    for (final method in ['POST', 'HEAD', 'PUT', 'DELETE']) {
      final answer = await rawRequest(url, method: method);
      expect(answer.status, 405, reason: method);
    }
    expect(resolver.calls, isEmpty);
  });

  test('a bad token, an unknown kind, a malformed key or an item never '
      'asked for: 404 with an empty body', () async {
    final url = await urlFor();
    final token = url.pathSegments.first;
    final last = token.substring(token.length - 1) == 'A' ? 'B' : 'A';
    for (final bad in [
      withSegment(url, 0, '${token.substring(0, token.length - 1)}$last'),
      withSegment(url, 0, token.substring(1)),
      withSegment(url, 0, '${token}x'),
      withSegment(url, 1, 'storage'),
      withSegment(url, 2, 'plugin-x'),
      withSegment(url, 3, 'never-asked'),
      url.replace(path: '${url.path}/extra'),
      url.replace(path: '/$token/source-plugin'),
    ]) {
      final answer = await rawRequest(bad);
      expect(answer.status, 404, reason: bad.path);
      expect(answer.body, isEmpty, reason: bad.path);
    }
    expect(resolver.calls, isEmpty);
  });

  test('several ranges: 416', () async {
    final answer = await rawRequest(await urlFor(), range: 'bytes=0-1,5-6');
    expect(answer.status, 416);
  });

  test('a range past the end: 416', () async {
    final answer = await rawRequest(await urlFor(), range: 'bytes=9000-');
    expect(answer.status, 416);
    expect(answer.headers['content-range'], 'bytes */2500');
  });

  test('a failed resolve: 502', () async {
    resolver.failing = true;
    final answer = await rawRequest(await urlFor(), range: 'bytes=0-');
    expect(answer.status, 502);
    expect(answer.body, isEmpty);
  });

  test('dropPlugin ends an open response at once, answers 404 for its items '
      'after it without a stream.js call, then tells the listeners', () async {
    upstream
      ..piece = 500
      ..pause = const Duration(milliseconds: 40);
    final url = await urlFor();
    final open = await OpenRawRequest.send(url, range: 'bytes=0-');
    await until(() => open.received.length > 600);

    proxy.dropPlugin(testInstallId);
    final before = open.received.length;
    await open.closed.timeout(const Duration(seconds: 2));

    // At most the piece already on its way arrives after the drop.
    expect(open.received.length - before, lessThanOrEqualTo(500));
    expect(parseRawAnswer(open.received).body.length, lessThan(2500));
    expect(dropped, [testInstallId]);

    final calls = resolver.calls.length;
    expect((await rawRequest(url, range: 'bytes=0-')).status, 404);
    // A new urlFor for a dropped plugin's item is refused too.
    final again = await urlFor(
      const RemoteSourceRef(installId: testInstallId, itemId: 'other'),
    );
    expect((await rawRequest(again, range: 'bytes=0-')).status, 404);
    expect(resolver.calls, hasLength(calls));

    proxy.dropPlugin(testInstallId);
    expect(dropped, [testInstallId], reason: 'dropped once');
  });

  test('a drop leaves the items of other plugins alone', () async {
    const other = RemoteSourceRef(
      installId: 'plugin-zzzzzzzzzzzz',
      itemId: 'x',
    );
    final url = await urlFor(other);
    proxy.dropPlugin(testInstallId);
    expect((await rawRequest(url, range: 'bytes=0-')).status, 206);
  });

  test('a restored plugin is served again from its next urlFor', () async {
    await urlFor();
    proxy
      ..dropPlugin(testInstallId)
      ..restorePlugin(testInstallId);
    final answer = await rawRequest(await urlFor(), range: 'bytes=0-');
    expect(answer.status, 206);
    expect(answer.body, bytes);
  });

  test('the log never holds the token or the upstream URL', () async {
    final records = <String>[];
    final level = Logger.root.level;
    Logger.root.level = Level.ALL;
    final sub = Logger.root.onRecord.listen((r) => records.add(r.message));
    addTearDown(() async {
      await sub.cancel();
      Logger.root.level = level;
    });
    final url = await urlFor();
    await rawRequest(url, range: 'bytes=0-');
    upstream.forbidden.addAll({'/s1', '/s2'});
    await rawRequest(await urlFor(), range: 'bytes=0-');
    proxy.dropPlugin(testInstallId);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(records, isNotEmpty);
    final token = url.pathSegments.first;
    for (final message in records) {
      expect(message, isNot(contains(token)));
      expect(message, isNot(contains('127.0.0.1:${upstream.url('/').port}')));
      expect(message, isNot(contains('/s1')));
    }
  });
}
