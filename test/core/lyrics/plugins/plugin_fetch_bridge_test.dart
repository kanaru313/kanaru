import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http_retry.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_fetch_bridge.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';
import 'package:logging/logging.dart';

import '../../lyrics_translation/loopback_server.dart';

/// A [LyricsHttp] whose `send` is a closure, to script every failure.
class _StubHttp implements LyricsHttp {
  _StubHttp(this.handler);

  final Future<LyricsHttpRawResponse> Function(
    LyricsHttpRequest request,
    void Function()? onSend,
  )
  handler;
  LyricsHttpRequest? last;

  @override
  Future<LyricsHttpRawResponse> send(
    LyricsHttpRequest request, {
    void Function()? onSend,
  }) {
    last = request;
    return handler(request, onSend);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PluginFetchCall _call(
  Uri url, {
  String method = 'GET',
  List<(String, String)> headers = const [],
  int maxSends = 10,
}) => PluginFetchCall(
  method: method,
  url: url,
  headers: headers,
  body: Uint8List(0),
  deadline: const Duration(seconds: 5),
  maxSends: maxSends,
);

final _url = Uri.parse(
  'https://api.example.org/v1/search?q=secret&k=token#frag',
);

void main() {
  group('failures become outcomes', () {
    final cases = <(String, Object, PluginFetchOutcome)>[
      (
        'network',
        const LyricsFetchException(LyricsFetchKind.network),
        PluginFetchOutcome.network,
      ),
      (
        'server',
        const LyricsFetchException(LyricsFetchKind.server),
        PluginFetchOutcome.network,
      ),
      (
        'invalidResponse',
        const LyricsFetchException(LyricsFetchKind.invalidResponse),
        PluginFetchOutcome.invalidResponse,
      ),
      (
        'blockedHost',
        const LyricsFetchException(LyricsFetchKind.blockedHost),
        PluginFetchOutcome.blockedHost,
      ),
      (
        'notConsented',
        const LyricsFetchException(LyricsFetchKind.notConsented),
        PluginFetchOutcome.notConsented,
      ),
      (
        'rejected',
        const LyricsRequestRejected('method'),
        PluginFetchOutcome.invalidRequest,
      ),
      (
        'abandoned',
        const LyricsRequestAbandoned(),
        PluginFetchOutcome.abandoned,
      ),
      (
        'any other error',
        StateError('boom with a secret'),
        PluginFetchOutcome.network,
      ),
    ];
    for (final (name, error, outcome) in cases) {
      test('$name -> ${outcome.name}, one send at least', () async {
        final bridge = PluginFetchBridge(_StubHttp((_, _) => throw error));
        final answer = await bridge.call(_call(_url));
        expect(answer.outcome, outcome);
        expect(answer.sends, 1);
        expect(answer.retryAfterSec, isNull);
      });
    }

    test('rateLimited carries retryAfter in whole seconds', () async {
      final bridge = PluginFetchBridge(
        _StubHttp(
          (_, _) => throw const LyricsFetchException(
            LyricsFetchKind.rateLimited,
            retryAfter: Duration(seconds: 42),
          ),
        ),
      );
      final answer = await bridge.call(_call(_url));
      expect(answer.outcome, PluginFetchOutcome.rateLimited);
      expect(answer.retryAfterSec, 42);
    });

    test('a failed call reports the sends that went out', () async {
      final bridge = PluginFetchBridge(
        _StubHttp((_, onSend) {
          onSend!();
          onSend();
          onSend();
          throw const LyricsFetchException(LyricsFetchKind.network);
        }),
      );
      final answer = await bridge.call(_call(_url));
      expect(answer.sends, 3);
    });

    test('a thrown error never reaches the caller or the log', () async {
      final records = <String>[];
      final sub = Logger.root.onRecord.listen(
        (r) => records.add('${r.message} ${r.error}'),
      );
      addTearDown(sub.cancel);
      final bridge = PluginFetchBridge(
        _StubHttp((_, _) => throw StateError('Bearer top-secret-token')),
      );
      await bridge.call(_call(_url));
      expect(records.join(), isNot(contains('top-secret')));
    });
  });

  test('ok maps status, url, headers, bytes and sends', () async {
    final bridge = PluginFetchBridge(
      _StubHttp(
        (request, onSend) async => LyricsHttpRawResponse(
          status: 201,
          bytes: Uint8List.fromList([1, 2, 3]),
          headers: const {'content-type': 'text/plain', 'x-a': 'b'},
          url: request.uri,
          sends: 2,
        ),
      ),
    );
    final answer = await bridge.call(_call(_url));
    expect(answer.outcome, PluginFetchOutcome.ok);
    expect(answer.status, 201);
    expect(answer.url, _url);
    expect(answer.headers, [('content-type', 'text/plain'), ('x-a', 'b')]);
    expect(answer.bytes, [1, 2, 3]);
    expect(answer.sends, 2);
  });

  test('the call is passed on with its deadline and send cap', () async {
    final stub = _StubHttp(
      (request, _) async => LyricsHttpRawResponse(
        status: 200,
        bytes: Uint8List(0),
        headers: const {},
        url: request.uri,
        sends: 1,
      ),
    );
    await PluginFetchBridge(
      stub,
    ).call(_call(_url, method: 'POST', headers: [('X-Key', 'v')], maxSends: 4));
    final sent = stub.last!;
    expect((sent.method, sent.uri, sent.maxSends), ('POST', _url, 4));
    expect(sent.deadline, const Duration(seconds: 5));
    expect(sent.headers, {'X-Key': 'v'});
    expect(sent.body, isNull);
  });

  group('request records', () {
    test('keep method, host, path and status, never the query', () async {
      final bridge = PluginFetchBridge(
        _StubHttp(
          (request, _) async => LyricsHttpRawResponse(
            status: 404,
            bytes: Uint8List(0),
            headers: const {},
            url: request.uri,
            sends: 1,
          ),
        ),
      );
      await bridge.call(_call(_url));
      final record = bridge.requests.single.toJson();
      expect(record['method'], 'GET');
      expect(record['host'], 'api.example.org');
      expect(record['path'], '/v1/search');
      expect(record['status'], 404);
      expect(record['ms'], isA<int>());
      expect(record.toString(), isNot(contains('secret')));
      expect(record.toString(), isNot(contains('token')));
      expect(record.toString(), isNot(contains('frag')));
    });

    test('a failed call has a null status; one record per call', () async {
      final bridge = PluginFetchBridge(
        _StubHttp(
          (_, _) => throw const LyricsFetchException(LyricsFetchKind.network),
        ),
      );
      await bridge.call(_call(_url));
      await bridge.call(_call(_url, method: 'POST'));
      expect(bridge.requests.map((r) => r.status), [null, null]);
      expect(bridge.requests.map((r) => r.method), ['GET', 'POST']);
    });

    test('a call that never answers is listed with no status', () async {
      final never = Completer<LyricsHttpRawResponse>();
      final bridge = PluginFetchBridge(_StubHttp((_, _) => never.future));
      unawaited(bridge.call(_call(_url)));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final record = bridge.requests.single;
      expect(record.status, isNull);
      expect(record.host, 'api.example.org');
      expect(record.ms, greaterThanOrEqualTo(50));
    });

    test('the time is measured around send', () async {
      final bridge = PluginFetchBridge(
        _StubHttp((_, _) async {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          throw const LyricsFetchException(LyricsFetchKind.network);
        }),
      );
      await bridge.call(_call(_url));
      expect(bridge.requests.single.ms, greaterThanOrEqualTo(50));
    });
  });

  group('over a real LyricsHttp', () {
    late HttpClient client;
    late LoopbackServer server;

    setUp(() async {
      client = HttpClient();
      server = await LoopbackServer.start((_) => const Reply(200, 'hello'));
    });
    tearDown(() async {
      client.close(force: true);
      await server.close();
    });

    PluginFetchBridge bridge({bool Function()? allowed}) => PluginFetchBridge(
      LyricsHttp.forTesting(
        client: client,
        hosts: const ['127.0.0.1'],
        sleep: (_) async {},
        allowed: allowed,
      ),
    );

    test('an ok answer comes back with its bytes', () async {
      final answer = await bridge().call(
        _call(server.baseUri.replace(path: '/x')),
      );
      expect(answer.outcome, PluginFetchOutcome.ok);
      expect(String.fromCharCodes(answer.bytes), 'hello');
      expect(answer.sends, 1);
    });

    test('a header value with CR/LF sends nothing: invalidRequest', () async {
      final b = bridge();
      final answer = await b.call(
        _call(
          server.baseUri.replace(path: '/x'),
          headers: [('X-Key', 'a\r\nInjected: 1')],
        ),
      );
      expect(answer.outcome, PluginFetchOutcome.invalidRequest);
      expect(server.requests, isEmpty);
      expect(b.requests.single.status, isNull);
    });

    test('a host that is not allowed is blockedHost, nothing sent', () async {
      final answer = await bridge().call(
        _call(Uri.parse('http://localhost:1/x')),
      );
      expect(answer.outcome, PluginFetchOutcome.blockedHost);
      expect(answer.sends, 1);
    });

    test('withdrawn consent is notConsented, nothing sent', () async {
      final answer = await bridge(allowed: () => false)
          .call(_call(server.baseUri.replace(path: '/x')));
      expect(answer.outcome, PluginFetchOutcome.notConsented);
      expect(server.requests, isEmpty);
    });

    test('retries stop at the send cap of the call', () async {
      server.handler = (_) =>
          const Reply(503, '', headers: {'retry-after': '1'});
      final answer = await bridge().call(
        _call(server.baseUri.replace(path: '/x'), maxSends: 2),
      );
      expect(answer.outcome, PluginFetchOutcome.ok);
      expect((answer.status, answer.sends), (503, 2));
      expect(server.requests, hasLength(2));
    });
  });
}
