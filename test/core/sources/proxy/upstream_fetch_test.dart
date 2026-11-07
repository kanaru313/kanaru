import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/proxy/stream_resolver.dart';
import 'package:kanaru/core/sources/proxy/upstream_fetch.dart';
import 'package:kanaru/core/sources/proxy/upstream_reader.dart'
    show upstreamFailureReason;

import 'proxy_test_support.dart';

void main() {
  late FakeUpstream upstream;
  late HttpClient client;
  final bytes = testBytes(2000);

  setUp(() async {
    upstream = await FakeUpstream.start(bytes);
    // Plain loopback client: the public-only connector and the URL rules are
    // tested on their own.
    client = HttpClient()..autoUncompress = false;
    addTearDown(() async {
      client.close(force: true);
      await upstream.close();
    });
  });

  ResolvedStream streamOf(
    String path, {
    bool Function(Uri url)? redirectAllowed,
  }) => ResolvedStream(
    url: upstream.url(path),
    headers: const {'x-plugin': 'yes', 'user-agent': 'PluginAgent'},
    allowed: () => true,
    redirectAllowed: redirectAllowed,
  );

  Future<({HttpClientResponse response, Uri url})> fetch(
    ResolvedStream stream, {
    ({int start, int end})? range,
    Duration? headerTimeout,
  }) => headerTimeout == null
      ? fetchUpstream(client, stream, stream.url, range: range)
      : fetchUpstream(
          client,
          stream,
          stream.url,
          range: range,
          headerTimeout: headerTimeout,
        );

  /// What [fetch] refuses with, as the log shows it.
  Future<String> refusal(ResolvedStream stream) async {
    try {
      await fetch(stream);
    } on Object catch (error) {
      return upstreamFailureReason(error);
    }
    fail('the request was not refused');
  }

  group('fetchUpstream', () {
    test('sends the stream headers and identity; no range: none', () async {
      final result = await fetch(streamOf('/a'));
      expect(result.response.statusCode, 200);
      expect(result.url, upstream.url('/a'));
      expect(await result.response.fold<int>(0, (n, d) => n + d.length), 2000);
      final request = upstream.requests.single;
      expect(request.headers.value('accept-encoding'), 'identity');
      expect(request.headers.value('x-plugin'), 'yes');
      expect(request.headers.value('user-agent'), 'PluginAgent');
      expect(request.range, isNull);
    });

    test('a closed range sends bytes=start-end', () async {
      final result = await fetch(streamOf('/a'), range: (start: 10, end: 19));
      expect(result.response.statusCode, 206);
      expect(upstream.ranges, ['bytes=10-19']);
      final body = <int>[];
      await result.response.forEach(body.addAll);
      expect(body, bytes.sublist(10, 20));
    });

    test('hands a non-redirect status back to the caller', () async {
      upstream.forbidden.add('/a');
      final result = await fetch(streamOf('/a'));
      expect(result.response.statusCode, 403);
      await result.response.drain<void>();
    });

    test('a redirect to an allowed host is followed; url is the target, '
        'with the same headers and range', () async {
      upstream.redirected.add('/a');
      final result = await fetch(
        streamOf('/a', redirectAllowed: (url) => url.path == '/elsewhere'),
        range: (start: 0, end: 4),
      );
      expect(result.url, upstream.url('/elsewhere'));
      expect(result.response.statusCode, 206);
      await result.response.drain<void>();
      expect(upstream.requests.map((r) => r.path), ['/a', '/elsewhere']);
      for (final request in upstream.requests) {
        expect(request.range, 'bytes=0-4');
        expect(request.headers.value('x-plugin'), 'yes');
        expect(request.headers.value('accept-encoding'), 'identity');
      }
    });

    test('url is the last target after several redirects', () async {
      upstream
        ..redirected.addAll(['/a', '/r1', '/r2'])
        ..redirectTo.addAll({'/a': '/r1', '/r1': '/r2', '/r2': '/end'});
      final result = await fetch(streamOf('/a', redirectAllowed: (_) => true));
      expect(result.url, upstream.url('/end'));
      await result.response.drain<void>();
    });

    test('a redirect to a host the stream does not allow is refused', () async {
      upstream.redirected.add('/a');
      expect(
        await refusal(streamOf('/a', redirectAllowed: (_) => false)),
        'upstream redirect refused (302)',
      );
      // Only the first request went out.
      expect(upstream.requests.map((r) => r.path), ['/a']);
    });

    test('a redirect is refused when the stream names no rule', () async {
      upstream.redirected.add('/a');
      expect(await refusal(streamOf('/a')), 'upstream redirect refused (302)');
    });

    test('a fourth redirect is refused', () async {
      upstream
        ..redirected.addAll(['/a', '/r1', '/r2', '/r3'])
        ..redirectTo.addAll({'/a': '/r1', '/r1': '/r2', '/r2': '/r3'});
      expect(
        await refusal(streamOf('/a', redirectAllowed: (_) => true)),
        'too many upstream redirects',
      );
      expect(upstream.requests.map((r) => r.path), ['/a', '/r1', '/r2', '/r3']);
    });

    test('a redirect with no Location is refused', () async {
      final server = await _serve((request, response) {
        response.statusCode = HttpStatus.found;
      });
      addTearDown(() => server.close(force: true));
      expect(
        await refusal(
          ResolvedStream(
            url: Uri.parse('http://127.0.0.1:${server.port}/a'),
            headers: const {},
            allowed: () => true,
            redirectAllowed: (_) => true,
          ),
        ),
        'upstream redirect refused (302)',
      );
    });

    test('a relative Location is resolved against the asked URL, then '
        'judged by the stream like any target', () async {
      final seen = <Uri>[];
      final server = await _serve((request, response) {
        if (request.uri.path == '/a') {
          response
            ..statusCode = HttpStatus.found
            ..headers.set('location', '/next/part');
        }
      });
      addTearDown(() => server.close(force: true));
      final base = Uri.parse('http://127.0.0.1:${server.port}/a');
      ResolvedStream streamWith(bool allow) => ResolvedStream(
        url: base,
        headers: const {},
        allowed: () => true,
        redirectAllowed: (url) {
          seen.add(url);
          return allow;
        },
      );
      expect(
        await refusal(streamWith(false)),
        'upstream redirect refused (302)',
      );
      expect(seen, [base.resolve('/next/part')]);
      final result = await fetch(streamWith(true));
      expect(result.url, base.resolve('/next/part'));
      await result.response.drain<void>();
    });

    test('the header timeout aborts the request', () async {
      final hold = Completer<void>();
      final server = await _serve((request, response) => hold.future);
      addTearDown(() async {
        hold.complete();
        await server.close(force: true);
      });
      final stream = ResolvedStream(
        url: Uri.parse('http://127.0.0.1:${server.port}/a'),
        headers: const {},
        allowed: () => true,
      );
      await expectLater(
        fetch(stream, headerTimeout: const Duration(milliseconds: 100)),
        throwsA(
          isA<UpstreamRefused>().having(
            (e) => e.reason,
            'reason',
            'upstream headers timed out',
          ),
        ),
      );
    });

    test('the default header timeout is the shared constant', () {
      expect(upstreamHeaderTimeout, const Duration(seconds: 15));
      expect(maxUpstreamRedirects, 3);
    });
  });

  group('readUpstreamBody', () {
    Future<HttpClientResponse> open(String path) async =>
        (await fetch(streamOf(path))).response;

    test('returns the whole body', () async {
      final body = await readUpstreamBody(
        await open('/a'),
        maxBytes: 5000,
        timeout: const Duration(seconds: 5),
      );
      expect(body, bytes);
    });

    test('a body of exactly maxBytes is returned', () async {
      upstream.piece = 300;
      final body = await readUpstreamBody(
        await open('/a'),
        maxBytes: 2000,
        timeout: const Duration(seconds: 5),
      );
      expect(body, bytes);
    });

    test('maxBytes + 1 throws', () async {
      await expectLater(
        readUpstreamBody(
          await open('/a'),
          maxBytes: 1999,
          timeout: const Duration(seconds: 5),
        ),
        throwsA(
          isA<UpstreamBodyFailure>().having(
            (e) => e.kind,
            'kind',
            UpstreamBodyFailureKind.tooLong,
          ),
        ),
      );
    });

    test('a body past maxBytes with no declared length is cut: the rest '
        'is not read', () async {
      upstream
        ..omitLengths = true
        ..piece = 100
        ..pause = const Duration(milliseconds: 20);
      await expectLater(
        readUpstreamBody(
          await open('/a'),
          maxBytes: 1000,
          timeout: const Duration(seconds: 5),
        ),
        throwsA(
          isA<UpstreamBodyFailure>().having(
            (e) => e.reason,
            'reason',
            'upstream body too long',
          ),
        ),
      );
      await until(() => upstream.cutShort == 1);
    });

    test('a declared length above maxBytes throws before reading', () async {
      upstream
        ..piece = 100
        ..pause = const Duration(milliseconds: 20);
      final response = await open('/a');
      await expectLater(
        readUpstreamBody(
          response,
          maxBytes: 100,
          timeout: const Duration(seconds: 5),
        ),
        throwsA(isA<UpstreamBodyFailure>()),
      );
      await until(() => upstream.cutShort == 1);
    });

    test('a body that stalls past the timeout throws', () async {
      upstream
        ..piece = 100
        ..pause = const Duration(seconds: 2);
      final response = await open('/a');
      final failure = await readUpstreamBody(
        response,
        maxBytes: 5000,
        timeout: const Duration(milliseconds: 150),
      ).then<Object?>((_) => null, onError: (Object e) => e);
      expect(
        failure,
        isA<UpstreamBodyFailure>().having(
          (e) => e.kind,
          'kind',
          UpstreamBodyFailureKind.tooSlow,
        ),
      );
      expect(upstreamFailureReason(failure!), 'upstream body too slow');
      await until(() => upstream.cutShort == 1);
    });
  });
}

/// A loopback server answering every request with [handler]; the handler
/// may leave the response open.
Future<HttpServer> _serve(
  FutureOr<void> Function(HttpRequest request, HttpResponse response) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final response = request.response;
    await handler(request, response);
    await response.close();
  });
  return server;
}
