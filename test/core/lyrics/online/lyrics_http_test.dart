import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/app_identity.dart';
import 'package:kanaru/core/logging/app_logging.dart';
import 'package:kanaru/core/lyrics/online/lrclib_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';

import '../../lyrics_translation/loopback_server.dart';

Future<LyricsFetchKind> _kindOf(Future<Object?> call) async {
  try {
    await call;
  } on LyricsFetchException catch (e) {
    return e.kind;
  }
  throw StateError('expected a LyricsFetchException');
}

void main() {
  late HttpClient client;
  late LoopbackServer server;

  setUp(() async {
    client = HttpClient();
    server = await LoopbackServer.start((_) => const Reply(200, '{}'));
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  LyricsHttp production() =>
      LyricsHttp(LyricsProviderRegistration(LrclibProvider()), client);
  LyricsHttp testing() =>
      LyricsHttp.forTesting(client: client, hosts: const ['127.0.0.1']);

  test('a host that is not registered is blocked before any socket', () async {
    final uri = server.baseUri.replace(path: '/x');
    expect(
      await _kindOf(testing().get(Uri.parse('http://localhost:${uri.port}/x'))),
      LyricsFetchKind.blockedHost,
    );
    expect(await _kindOf(production().get(uri)), LyricsFetchKind.blockedHost);
    expect(server.requests, isEmpty);
  });

  test(
    'the production constructor refuses http, a port and user info',
    () async {
      final http = production();
      for (final url in [
        'http://lrclib.net/api/get',
        'https://lrclib.net:8443/api/get',
        'https://user@lrclib.net/api/get',
      ]) {
        expect(
          await _kindOf(http.get(Uri.parse(url))),
          LyricsFetchKind.blockedHost,
          reason: url,
        );
      }
      expect(server.requests, isEmpty);
    },
  );

  test('sends GET with only the app User-Agent', () async {
    await testing().get(server.baseUri.replace(path: '/api/get'));
    final request = server.requests.single;
    expect(request.method, 'GET');
    expect(
      request.header('user-agent'),
      'Kanaru/$kanaruVersion (+$kanaruRepositoryUrl)',
    );
    expect(request.header('lrclib-app-id'), isNull);
  });

  test('a redirect is returned, not followed', () async {
    server.handler = (r) => r.uri.path == '/start'
        ? const Reply(302, '', headers: {'location': '/other'})
        : const Reply(200, '{}');
    final response = await testing().get(
      server.baseUri.replace(path: '/start'),
    );
    expect(response.status, 302);
    expect(server.requests, hasLength(1));
  });

  test('a 3 MiB body is accepted and a 5 MiB body is rejected', () async {
    server.handler = (_) => Reply(200, 'a' * (3 * 1024 * 1024));
    expect((await testing().get(server.baseUri)).body.length, 3 * 1024 * 1024);
    server.handler = (_) => Reply(200, 'a' * (5 * 1024 * 1024));
    expect(
      await _kindOf(testing().get(server.baseUri)),
      LyricsFetchKind.invalidResponse,
    );
  });

  test('a connection that fails is a network error', () async {
    final uri = server.baseUri;
    await server.close();
    expect(await _kindOf(testing().get(uri)), LyricsFetchKind.network);
    server = await LoopbackServer.start((_) => const Reply(200, '{}'));
  });

  test('Retry-After is whole seconds clamped to 1 s..15 min', () {
    expect(parseRetryAfter('7'), const Duration(seconds: 7));
    expect(parseRetryAfter('0'), const Duration(seconds: 1));
    expect(parseRetryAfter('99999'), const Duration(minutes: 15));
    expect(
      parseRetryAfter('99999999999999999999999'),
      const Duration(minutes: 15),
    );
    expect(parseRetryAfter('Wed, 21 Oct 2026 07:28:00 GMT'), isNull);
    expect(parseRetryAfter('soon'), isNull);
    expect(parseRetryAfter('-5'), isNull);
    expect(parseRetryAfter(null), isNull);
  });
}
