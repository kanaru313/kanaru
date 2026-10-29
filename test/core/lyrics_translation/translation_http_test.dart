import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_http.dart';

import 'loopback_server.dart';

Future<TranslationFailureKind> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on TranslationException catch (e) {
    return e.kind;
  }
  throw StateError('expected a TranslationException');
}

void main() {
  late HttpClient client;
  late LoopbackServer server;

  setUp(() => client = HttpClient());
  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  test('returns status, body and lower-case headers for any status', () async {
    server = await LoopbackServer.start(
      (_) => const Reply(500, 'oops', headers: {'X-Trace-ID': 't-1'}),
    );
    final response = await sendTranslationRequest(
      client,
      method: 'GET',
      uri: server.baseUri,
    );
    expect(response.status, 500);
    expect(response.body, 'oops');
    expect(response.headers['x-trace-id'], 't-1');
  });

  test('sends method, headers and UTF-8 body', () async {
    server = await LoopbackServer.start((_) => const Reply(200, 'ok'));
    await sendTranslationRequest(
      client,
      method: 'POST',
      uri: server.baseUri.replace(path: '/x'),
      headers: {'x-custom': 'v'},
      body: 'đêm',
    );
    final seen = server.requests.single;
    expect(seen.method, 'POST');
    expect(seen.uri.path, '/x');
    expect(seen.header('x-custom'), 'v');
    expect(seen.body, 'đêm');
  });

  test('refused connection is a network failure', () async {
    server = await LoopbackServer.start((_) => const Reply(200, ''));
    final closed = await LoopbackServer.start((_) => const Reply(200, ''));
    final uri = closed.baseUri;
    await closed.close();
    expect(
      await _failureOf(sendTranslationRequest(client, method: 'GET', uri: uri)),
      TranslationFailureKind.network,
    );
  });

  test(
    'a reply slower than the request timeout is a network failure',
    () async {
      server = await LoopbackServer.start(
        (_) => const Reply(200, 'late', delay: Duration(milliseconds: 800)),
      );
      expect(
        await _failureOf(
          sendTranslationRequest(
            client,
            method: 'GET',
            uri: server.baseUri,
            requestTimeout: const Duration(milliseconds: 100),
          ),
        ),
        TranslationFailureKind.network,
      );
    },
  );

  test('a body over the cap is an invalid response', () async {
    server = await LoopbackServer.start(
      (_) => Reply(
        200,
        '',
        bodyBytes: List.filled(maxTranslationResponseBytes + 1, 0x61),
      ),
    );
    expect(
      await _failureOf(
        sendTranslationRequest(client, method: 'GET', uri: server.baseUri),
      ),
      TranslationFailureKind.invalidResponse,
    );
  });

  test('a larger cap passed by the caller is honored', () async {
    server = await LoopbackServer.start(
      (_) => Reply(
        200,
        '',
        bodyBytes: List.filled(maxTranslationResponseBytes + 1, 0x61),
      ),
    );
    final response = await sendTranslationRequest(
      client,
      method: 'GET',
      uri: server.baseUri,
      maxBytes: 2 * maxTranslationResponseBytes,
    );
    expect(response.body.length, maxTranslationResponseBytes + 1);
  });

  test('a body that is not UTF-8 is an invalid response', () async {
    server = await LoopbackServer.start(
      (_) => const Reply(200, '', bodyBytes: [0xff, 0xfe, 0xfd]),
    );
    expect(
      await _failureOf(
        sendTranslationRequest(client, method: 'GET', uri: server.baseUri),
      ),
      TranslationFailureKind.invalidResponse,
    );
  });

  test('a header value Dart refuses is badKey and leaks nothing', () async {
    server = await LoopbackServer.start((_) => const Reply(200, ''));
    const secret = 'line1\nSECRET-VALUE';
    Object? caught;
    try {
      await sendTranslationRequest(
        client,
        method: 'GET',
        uri: server.baseUri,
        headers: {'authorization': secret},
      );
    } catch (e) {
      caught = e;
    }
    expect(caught, isA<TranslationException>());
    expect(
      (caught! as TranslationException).kind,
      TranslationFailureKind.badKey,
    );
    expect(caught.toString(), isNot(contains('SECRET-VALUE')));
    expect(server.requests, isEmpty);
  });

  test(
    'a body that stalls half way is a network failure and closes the socket',
    () async {
      server = await LoopbackServer.start(
        (_) => const Reply(
          200,
          '{"some":"long enough body"}',
          stallAfterPartial: true,
        ),
      );
      expect(
        await _failureOf(
          sendTranslationRequest(
            client,
            method: 'GET',
            uri: server.baseUri,
            requestTimeout: const Duration(milliseconds: 100),
          ),
        ),
        TranslationFailureKind.network,
      );
      // The client must hang up, not leave the socket open.
      await server.stalledClientClosed.timeout(
        const Duration(seconds: 2),
        onTimeout: () => fail('connection was left open'),
      );
    },
  );

  test(
    'an error status with a body that is not UTF-8 keeps its status',
    () async {
      server = await LoopbackServer.start(
        (_) => const Reply(429, '', bodyBytes: [0xff]),
      );
      final response = await sendTranslationRequest(
        client,
        method: 'GET',
        uri: server.baseUri,
      );
      expect(response.status, 429);
    },
  );

  test('a closed client is a network failure', () async {
    server = await LoopbackServer.start((_) => const Reply(200, ''));
    client.close(force: true);
    expect(
      await _failureOf(
        sendTranslationRequest(client, method: 'GET', uri: server.baseUri),
      ),
      TranslationFailureKind.network,
    );
  });

  test('redirects are not followed', () async {
    server = await LoopbackServer.start(
      (_) => const Reply(
        302,
        '',
        headers: {'location': 'http://127.0.0.1:1/elsewhere'},
      ),
    );
    final response = await sendTranslationRequest(
      client,
      method: 'GET',
      uri: server.baseUri,
    );
    expect(response.status, 302);
    expect(server.requests, hasLength(1));
  });

  test(
    'a request still connecting at the timeout is aborted once open',
    () async {
      server = await LoopbackServer.start((_) => const Reply(200, ''));
      final opening = Completer<HttpClientRequest>();
      final request = _FakeRequest();
      final fake = _SlowClient(opening.future);
      expect(
        await _failureOf(
          sendTranslationRequest(
            fake,
            method: 'GET',
            uri: server.baseUri,
            connectTimeout: const Duration(milliseconds: 50),
          ),
        ),
        TranslationFailureKind.network,
      );
      opening.complete(request);
      await Future<void>.delayed(Duration.zero);
      expect(request.aborted, isTrue);
    },
  );
}

/// A client whose connection never opens until the test says so.
class _SlowClient implements HttpClient {
  _SlowClient(this._opening);

  final Future<HttpClientRequest> _opening;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => _opening;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  bool aborted = false;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) => aborted = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
