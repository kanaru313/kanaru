import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/app_logging.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http_retry.dart';

import '../../lyrics_translation/loopback_server.dart';

Matcher _kind(LyricsFetchKind kind) =>
    throwsA(isA<LyricsFetchException>().having((e) => e.kind, 'kind', kind));

void main() {
  late HttpClient client;
  late LoopbackServer server;
  var abandoned = false;
  var allowed = true;

  setUp(() async {
    client = HttpClient();
    abandoned = false;
    allowed = true;
    server = await LoopbackServer.start((_) => const Reply(200, 'ok'));
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  LyricsHttp http({
    LyricsSleep sleep = realLyricsSleep,
    Duration overallTimeout = lyricsOverallTimeout,
  }) => LyricsHttp.forTesting(
    client: client,
    hosts: const ['127.0.0.1'],
    sleep: sleep,
    abandoned: () => abandoned,
    allowed: () => allowed,
    overallTimeout: overallTimeout,
  );

  LyricsHttpRequest request({
    String method = 'GET',
    Map<String, String> headers = const {},
    List<int>? body,
    Duration? deadline,
    int? maxSends,
    String path = '/x',
  }) => LyricsHttpRequest(
    method: method,
    uri: server.baseUri.replace(path: path),
    headers: headers,
    body: body,
    deadline: deadline,
    maxSends: maxSends,
  );

  test(
    'POST sends the body and the plugin header, returns raw bytes',
    () async {
      server.handler = (_) => const Reply(
        201,
        '',
        bodyBytes: [0xff, 0xfe, 0x00, 0x41],
        headers: {'x-a': '1', 'content-type': 'application/octet-stream'},
      );
      final response = await http().send(
        request(
          method: 'POST',
          headers: {'X-Token': 'secret', 'Content-Type': 'application/json'},
          body: utf8.encode('{"q":"é"}'),
        ),
      );
      final seen = server.requests.single;
      expect(seen.method, 'POST');
      expect(seen.body, '{"q":"é"}');
      expect(seen.header('x-token'), 'secret');
      expect(seen.header('content-type'), startsWith('application/json'));
      expect(response.status, 201);
      expect(response.bytes, [0xff, 0xfe, 0x00, 0x41]);
      expect(response.headers['x-a'], '1');
      expect(response.url, server.baseUri.replace(path: '/x'));
      expect(response.sends, 1);
    },
  );

  test(
    'user-agent is the app\'s, accept defaults, any accept is kept',
    () async {
      await http().send(
        request(headers: {'User-Agent': 'evil', 'Host': 'evil.example'}),
      );
      await http().send(request(headers: {'accept': 'text/html'}));
      final first = server.requests[0];
      expect(first.header('user-agent'), startsWith('Kanaru/$kanaruVersion'));
      expect(first.header('accept'), '*/*');
      expect(first.header('host'), isNot('evil.example'));
      expect(server.requests[1].header('accept'), 'text/html');
    },
  );

  test('the plugin\'s accept-encoding never reaches the server', () async {
    await http().send(request(headers: {'Accept-Encoding': 'br'}));
    expect(server.requests.single.header('accept-encoding'), isNot('br'));
  });

  test('a rejected request sends nothing', () async {
    final bad = [
      request(method: 'PUT'),
      request(headers: {'x-a': 'a\r\nb: c'}),
      request(headers: {'bad name': 'x'}),
      request(headers: {'x-a': 'caf\u00e9'}),
      request(method: 'POST', body: [1, 300]),
      request(body: [1]),
      request(method: 'POST', body: List.filled(256 * 1024 + 1, 0)),
    ];
    for (final r in bad) {
      await expectLater(http().send(r), throwsA(isA<LyricsRequestRejected>()));
    }
    expect(server.requests, isEmpty);
  });

  test('an address that is not registered is blocked', () async {
    final uri = Uri.parse('http://localhost:${server.baseUri.port}/x');
    await expectLater(
      http().send(LyricsHttpRequest(method: 'GET', uri: uri)),
      _kind(LyricsFetchKind.blockedHost),
    );
    final strict = LyricsHttp.forTesting(client: client, hosts: const []);
    await expectLater(
      strict.send(request()),
      _kind(LyricsFetchKind.blockedHost),
    );
    expect(server.requests, isEmpty);
  });

  test('a body over 4 MiB is invalidResponse, 4 MiB passes', () async {
    server.handler = (_) =>
        Reply(200, '', bodyBytes: List.filled(lyricsMaxResponseBytes, 0x61));
    expect(
      (await http().send(request())).bytes,
      hasLength(lyricsMaxResponseBytes),
    );
    server.handler = (_) => Reply(
      200,
      '',
      bodyBytes: List.filled(lyricsMaxResponseBytes + 1, 0x61),
    );
    await expectLater(
      http().send(request()),
      _kind(LyricsFetchKind.invalidResponse),
    );
  });

  test('an error status is returned as an answer', () async {
    server.handler = (_) => const Reply(404, 'nope');
    final response = await http().send(request());
    expect(response.status, 404);
    expect(utf8.decode(response.bytes), 'nope');
  });

  test('consent withdrawn between sends gives notConsented', () async {
    server.handler = (_) => const Reply(503, '', headers: {'retry-after': '1'});
    await expectLater(
      http(sleep: (_) async => allowed = false).send(request()),
      _kind(LyricsFetchKind.notConsented),
    );
    expect(server.requests, hasLength(1));
  });

  test('consent withdrawn before the first send sends nothing', () async {
    allowed = false;
    await expectLater(
      http().send(request()),
      _kind(LyricsFetchKind.notConsented),
    );
    expect(server.requests, isEmpty);
  });

  test(
    'consent withdrawn during the overall timeout is notConsented',
    () async {
      server.handler = (_) =>
          const Reply(200, '{}', delay: Duration(milliseconds: 600));
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 30),
          () => allowed = false,
        ),
      );
      await expectLater(
        http(overallTimeout: const Duration(milliseconds: 100)).send(request()),
        _kind(LyricsFetchKind.notConsented),
      );
    },
  );

  test('abandoned before the first send: nothing reaches the server', () async {
    abandoned = true;
    await expectLater(
      http().send(request()),
      throwsA(isA<LyricsRequestAbandoned>()),
    );
    expect(server.requests, isEmpty);
  });

  test('abandoned during a busy wait: no second send', () async {
    server.handler = (_) => const Reply(503, '');
    await expectLater(
      http(sleep: (_) async => abandoned = true).send(request()),
      throwsA(isA<LyricsRequestAbandoned>()),
    );
    expect(server.requests, hasLength(1));
  });

  test('a deadline of 2 s ends a slow answer at 2 s', () async {
    server.handler = (_) =>
        const Reply(200, 'late', delay: Duration(seconds: 6));
    final clock = Stopwatch()..start();
    await expectLater(
      http().send(request(deadline: const Duration(seconds: 2))),
      _kind(LyricsFetchKind.network),
    );
    expect(clock.elapsed, greaterThanOrEqualTo(const Duration(seconds: 2)));
    expect(clock.elapsed, lessThan(const Duration(seconds: 4)));
  });

  test('a deadline above the overall timeout does not extend it', () async {
    server.handler = (_) =>
        const Reply(200, 'late', delay: Duration(milliseconds: 600));
    await expectLater(
      http(overallTimeout: const Duration(milliseconds: 100))
          .send(request(deadline: const Duration(seconds: 60))),
      _kind(LyricsFetchKind.network),
    );
  });

  test('a deadline with no time left sends nothing', () async {
    await expectLater(
      http().send(request(deadline: Duration.zero)),
      _kind(LyricsFetchKind.network),
    );
    expect(server.requests, isEmpty);
  });

  test('sends counts a retried 429 as 2', () async {
    var n = 0;
    server.handler = (_) => n++ == 0
        ? const Reply(429, '', headers: {'retry-after': '2'})
        : const Reply(200, 'ok');
    final response = await http(sleep: (_) async {}).send(request());
    expect(response.status, 200);
    expect(response.sends, 2);
    expect(server.requests, hasLength(2));
  });

  test('a POST body is sent again unchanged on a retry', () async {
    var n = 0;
    server.handler = (_) =>
        n++ == 0 ? const Reply(503, '') : const Reply(200, '');
    await http(sleep: (_) async {})
        .send(request(method: 'POST', body: utf8.encode('payload')));
    expect(server.requests.map((r) => r.body), ['payload', 'payload']);
  });

  test('onSend counts every send: three busy answers are three', () async {
    server.handler = (_) => const Reply(429, '', headers: {'retry-after': '1'});
    var sends = 0;
    final response = await http(sleep: (_) async {})
        .send(request(), onSend: () => sends++);
    expect(response.status, 429);
    expect(response.sends, 3);
    expect(sends, 3);
  });

  test('onSend counts the sends of a call that then fails', () async {
    server.handler = (_) => const Reply(503, '');
    var sends = 0;
    await expectLater(
      http(sleep: (_) async => allowed = false)
          .send(request(), onSend: () => sends++),
      _kind(LyricsFetchKind.notConsented),
    );
    expect(sends, 1);
  });

  test('onSend is not called for a rejected or abandoned request', () async {
    var sends = 0;
    await expectLater(
      http().send(request(method: 'PUT'), onSend: () => sends++),
      throwsA(isA<LyricsRequestRejected>()),
    );
    abandoned = true;
    await expectLater(
      http().send(request(), onSend: () => sends++),
      throwsA(isA<LyricsRequestAbandoned>()),
    );
    expect(sends, 0);
  });

  test('no time left and abandoned: abandoned, before consent', () async {
    abandoned = true;
    allowed = false;
    await expectLater(
      http().send(request(deadline: Duration.zero)),
      throwsA(isA<LyricsRequestAbandoned>()),
    );
    expect(server.requests, isEmpty);
  });

  test('the socket is closed at the deadline, not at 20 s', () async {
    server.handler = (_) => const Reply(200, 'x', stallAfterPartial: true);
    final clock = Stopwatch()..start();
    await expectLater(
      http().send(request(deadline: const Duration(milliseconds: 500))),
      _kind(LyricsFetchKind.network),
    );
    await server.stalledClientClosed.timeout(const Duration(seconds: 3));
    expect(clock.elapsed, lessThan(const Duration(seconds: 4)));
  });

  test('busy answer then a stall to the deadline is rateLimited', () async {
    var n = 0;
    server.handler = (_) => n++ == 0
        ? const Reply(429, '', headers: {'retry-after': '1'})
        : const Reply(200, 'late', delay: Duration(seconds: 6));
    await expectLater(
      http(sleep: (_) async {})
          .send(request(deadline: const Duration(milliseconds: 1500))),
      throwsA(
        isA<LyricsFetchException>()
            .having((e) => e.kind, 'kind', LyricsFetchKind.rateLimited)
            .having(
              (e) => e.retryAfter,
              'retryAfter',
              const Duration(seconds: 1),
            ),
      ),
    );
  });

  test(
    'changing the body during a busy wait does not change a retry',
    () async {
      final body = utf8.encode('payload');
      var n = 0;
      server.handler = (_) =>
          n++ == 0 ? const Reply(503, '') : const Reply(200, '');
      await http(sleep: (_) async => body[0] = 0x58)
          .send(request(method: 'POST', body: body));
      expect(server.requests.map((r) => r.body), ['payload', 'payload']);
    },
  );

  group('maxSends', () {
    setUp(() {
      server.handler = (_) =>
          const Reply(429, 'slow', headers: {'retry-after': '1'});
    });

    test('a cap of 1 sends once and returns the busy answer', () async {
      var sends = 0;
      final response = await http(sleep: (_) async {})
          .send(request(maxSends: 1), onSend: () => sends++);
      expect((response.status, response.sends, sends), (429, 1, 1));
      expect(server.requests, hasLength(1));
    });

    test('a cap of 2 allows one retry, not two', () async {
      final response = await http(sleep: (_) async {})
          .send(request(maxSends: 2));
      expect((response.status, response.sends), (429, 2));
      expect(server.requests, hasLength(2));
    });

    test('a cap of 0 still makes the first send', () async {
      final response = await http(sleep: (_) async {})
          .send(request(maxSends: 0));
      expect(response.sends, 1);
    });

    test('a cap above the retry limit changes nothing', () async {
      final response = await http(sleep: (_) async {})
          .send(request(maxSends: 10));
      expect(response.sends, 3);
    });

    test('without a cap the retries run as before', () async {
      final response = await http(sleep: (_) async {}).send(request());
      expect(response.sends, 3);
    });
  });
}
