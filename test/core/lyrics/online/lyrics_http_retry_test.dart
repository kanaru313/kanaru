import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http_retry.dart';

import '../../lyrics_translation/loopback_server.dart';

Reply _busy(int status, [String? retryAfter]) => Reply(
  status,
  '{"name":"ServerOverloaded"}',
  headers: {'retry-after': ?retryAfter},
);

const _ok = Reply(200, '{}', headers: {'content-type': 'application/json'});

void main() {
  late HttpClient client;
  late LoopbackServer server;
  late List<Duration> sleeps;
  var abandoned = false;

  setUp(() {
    client = HttpClient();
    sleeps = [];
    abandoned = false;
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  /// Answers [replies] in turn, the last one for every later request.
  Future<LyricsHttp> start(List<Reply> replies) async {
    var next = 0;
    server = await LoopbackServer.start(
      (_) => replies[next < replies.length ? next++ : replies.length - 1],
    );
    return LyricsHttp.forTesting(
      client: client,
      hosts: const ['127.0.0.1'],
      sleep: (wait) async => sleeps.add(wait),
      abandoned: () => abandoned,
    );
  }

  Uri get() => server.baseUri.replace(path: '/x');

  test('503 then 200 is sent twice after a 1 s wait', () async {
    final http = await start([_busy(503), _ok]);
    final response = await http.get(get());
    expect(response.status, 200);
    expect(server.requests, hasLength(2));
    expect(sleeps, [const Duration(seconds: 1)]);
  });

  test('503 three times: three sends, the last answer is returned', () async {
    final http = await start([_busy(503)]);
    final response = await http.get(get());
    expect(response.status, 503);
    expect(server.requests, hasLength(3));
    expect(sleeps, [const Duration(seconds: 1), const Duration(seconds: 1)]);
  });

  test('429 without Retry-After is not sent again', () async {
    final http = await start([_busy(429), _ok]);
    expect((await http.get(get())).status, 429);
    expect(server.requests, hasLength(1));
    expect(sleeps, isEmpty);
  });

  test('429 with Retry-After 3 waits 3 s and retries', () async {
    final http = await start([_busy(429, '3'), _ok]);
    expect((await http.get(get())).status, 200);
    expect(sleeps, [const Duration(seconds: 3)]);
  });

  test('Retry-After 5 is waited out, 6 and 30 are not', () async {
    var http = await start([_busy(503, '5'), _ok]);
    expect((await http.get(get())).status, 200);
    expect(sleeps, [const Duration(seconds: 5)]);
    await server.close();

    sleeps.clear();
    for (final header in ['6', '30']) {
      http = await start([_busy(503, header), _ok]);
      expect((await http.get(get())).status, 503, reason: header);
      expect(server.requests, hasLength(1), reason: header);
      expect(sleeps, isEmpty);
      await server.close();
    }
    server = await LoopbackServer.start((_) => _ok);
  });

  test('an HTTP-date Retry-After on a 503 counts as missing: 1 s', () async {
    final http = await start([
      _busy(503, 'Wed, 21 Oct 2026 07:28:00 GMT'),
      _ok,
    ]);
    expect((await http.get(get())).status, 200);
    expect(sleeps, [const Duration(seconds: 1)]);
  });

  test('other statuses are never retried', () async {
    final http = await start([const Reply(500, 'x'), _ok]);
    expect((await http.get(get())).status, 500);
    expect(server.requests, hasLength(1));
  });

  test('abandoned during the wait: no second send', () async {
    server = await LoopbackServer.start((_) => _busy(503));
    final http = LyricsHttp.forTesting(
      client: client,
      hosts: const ['127.0.0.1'],
      sleep: (wait) async {
        sleeps.add(wait);
        abandoned = true;
      },
      abandoned: () => abandoned,
    );
    await expectLater(http.get(get()), throwsA(isA<LyricsRequestAbandoned>()));
    expect(server.requests, hasLength(1));
  });

  test('abandoned during the first send: no wait, no second send', () async {
    server = await LoopbackServer.start((_) {
      abandoned = true;
      return _busy(503);
    });
    final http = LyricsHttp.forTesting(
      client: client,
      hosts: const ['127.0.0.1'],
      sleep: (wait) async => sleeps.add(wait),
      abandoned: () => abandoned,
    );
    await expectLater(http.get(get()), throwsA(isA<LyricsRequestAbandoned>()));
    expect(sleeps, isEmpty);
    expect(server.requests, hasLength(1));
  });

  test('abandoned before the first send: nothing is sent', () async {
    server = await LoopbackServer.start((_) => _ok);
    final http = LyricsHttp.forTesting(
      client: client,
      hosts: const ['127.0.0.1'],
      sleep: (wait) async => sleeps.add(wait),
      abandoned: () => true,
    );
    await expectLater(http.get(get()), throwsA(isA<LyricsRequestAbandoned>()));
    expect(sleeps, isEmpty);
    expect(server.requests, isEmpty);
  });

  test('busy then too slow to retry is rateLimited with Retry-After', () async {
    server = await LoopbackServer.start((_) => _busy(503, '2'));
    final never = Completer<void>();
    final http = LyricsHttp.forTesting(
      client: client,
      hosts: const ['127.0.0.1'],
      sleep: (_) => never.future,
      overallTimeout: const Duration(milliseconds: 100),
    );
    await expectLater(
      http.get(get()),
      throwsA(
        isA<LyricsFetchException>()
            .having((e) => e.kind, 'kind', LyricsFetchKind.rateLimited)
            .having(
              (e) => e.retryAfter,
              'retryAfter',
              const Duration(seconds: 2),
            ),
      ),
    );
    never.complete();
    await pumpEventQueue();
    expect(server.requests, hasLength(1));
  });

  test('a slow answer without a busy one is a network timeout', () async {
    server = await LoopbackServer.start(
      (_) => const Reply(200, '{}', delay: Duration(milliseconds: 600)),
    );
    final http = LyricsHttp.forTesting(
      client: client,
      hosts: const ['127.0.0.1'],
      overallTimeout: const Duration(milliseconds: 100),
    );
    await expectLater(
      http.get(get()),
      throwsA(
        isA<LyricsFetchException>().having(
          (e) => e.kind,
          'kind',
          LyricsFetchKind.network,
        ),
      ),
    );
  });

  test(
    'consent withdrawn before the overall timeout is not a timeout',
    () async {
      var allowed = true;
      server = await LoopbackServer.start(
        (_) => const Reply(200, '{}', delay: Duration(milliseconds: 600)),
      );
      final http = LyricsHttp.forTesting(
        client: client,
        hosts: const ['127.0.0.1'],
        overallTimeout: const Duration(milliseconds: 100),
        allowed: () => allowed,
      );
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 30),
          () => allowed = false,
        ),
      );
      await expectLater(
        http.get(get()),
        throwsA(
          isA<LyricsFetchException>().having(
            (e) => e.kind,
            'kind',
            LyricsFetchKind.notConsented,
          ),
        ),
      );
    },
  );

  test('consent withdrawn during a retry wait sends nothing more', () async {
    var allowed = true;
    server = await LoopbackServer.start((_) => _busy(503));
    final http = LyricsHttp.forTesting(
      client: client,
      hosts: const ['127.0.0.1'],
      sleep: (wait) async => allowed = false,
      allowed: () => allowed,
    );
    await expectLater(
      http.get(get()),
      throwsA(
        isA<LyricsFetchException>().having(
          (e) => e.kind,
          'kind',
          LyricsFetchKind.notConsented,
        ),
      ),
    );
    expect(server.requests, hasLength(1));
  });

  test('a network failure on the retry is a network error', () async {
    await start([_busy(503)]);
    final uri = get();
    final failing = LyricsHttp.forTesting(
      client: client,
      hosts: const ['127.0.0.1'],
      sleep: (wait) async {
        sleeps.add(wait);
        await server.close();
      },
    );
    await expectLater(
      failing.get(uri),
      throwsA(
        isA<LyricsFetchException>().having(
          (e) => e.kind,
          'kind',
          LyricsFetchKind.network,
        ),
      ),
    );
    server = await LoopbackServer.start((_) => _ok);
  });
}
