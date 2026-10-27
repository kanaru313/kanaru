import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/deepl_api.dart';
import 'package:kanaru/core/lyrics_translation/deepl_usage.dart';
import 'package:logging/logging.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';

import 'loopback_server.dart';

const _key = '00000000-0000-0000-0000-000000000000:fx';

String _fixture(String name) =>
    File('test/core/lyrics_translation/fixtures/$name').readAsStringSync();

void main() {
  late HttpClient client;
  late LoopbackServer server;

  setUp(() => client = HttpClient());
  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  Future<TranslationFailureKind> kindOf(String key) async {
    try {
      await fetchDeepLUsage(client, key, baseUri: server.baseUri);
    } on TranslationException catch (e) {
      return e.kind;
    }
    throw StateError('expected a TranslationException');
  }

  test('parses the counts and flags a free key', () async {
    server = await LoopbackServer.start(
      (_) => Reply(200, _fixture('deepl_usage.json')),
    );
    final usage = await fetchDeepLUsage(client, _key, baseUri: server.baseUri);
    expect(usage.characterCount, 180118);
    expect(usage.characterLimit, 500000);
    expect(usage.freeKey, isTrue);
    final seen = server.requests.single;
    expect(seen.method, 'GET');
    expect(seen.uri.path, '/v2/usage');
    expect(seen.header('authorization'), 'DeepL-Auth-Key $_key');
  });

  test('a paid key is not a free key', () async {
    server = await LoopbackServer.start(
      (_) => Reply(200, _fixture('deepl_usage.json')),
    );
    final usage = await fetchDeepLUsage(
      client,
      '00000000-0000-0000-0000-000000000000',
      baseUri: server.baseUri,
    );
    expect(usage.freeKey, isFalse);
  });

  test('403 is badKey', () async {
    server = await LoopbackServer.start((_) => const Reply(403, ''));
    expect(await kindOf(_key), TranslationFailureKind.badKey);
  });

  test('other statuses map like translating', () async {
    server = await LoopbackServer.start((_) => const Reply(456, ''));
    expect(await kindOf(_key), TranslationFailureKind.quotaExceeded);
    server.handler = (_) => const Reply(429, '');
    expect(await kindOf(_key), TranslationFailureKind.rateLimited);
    server.handler = (_) => const Reply(500, '');
    expect(await kindOf(_key), TranslationFailureKind.server);
  });

  test('malformed or incomplete JSON is an invalid response', () async {
    server = await LoopbackServer.start((_) => const Reply(200, 'nope'));
    expect(await kindOf(_key), TranslationFailureKind.invalidResponse);
    server.handler = (_) => const Reply(200, '{"character_count":1}');
    expect(await kindOf(_key), TranslationFailureKind.invalidResponse);
  });

  test('a key that cannot be one is badKey with no request', () async {
    server = await LoopbackServer.start((_) => const Reply(200, ''));
    expect(await kindOf('abc\ndef'), TranslationFailureKind.badKey);
    expect(server.requests, isEmpty);
  });

  test('a redirect is not followed and maps like any other status', () async {
    server = await LoopbackServer.start(
      (_) => const Reply(
        302,
        '',
        headers: {'location': 'http://127.0.0.1:1/elsewhere'},
      ),
    );
    expect(await kindOf(_key), TranslationFailureKind.invalidResponse);
    expect(server.requests, hasLength(1));
  });

  group('trace id in the log', () {
    late List<String> logged;
    late StreamSubscription<LogRecord> sub;
    const failure = TranslationException(
      TranslationFailureKind.rateLimited,
      statusCode: 429,
    );

    setUp(() async {
      logged = [];
      Logger.root.level = Level.ALL;
      sub = Logger.root.onRecord.listen((r) => logged.add(r.message));
      // The outer tearDown closes a server.
      server = await LoopbackServer.start((_) => const Reply(200, ''));
    });
    tearDown(() => sub.cancel());

    test('a plain id is logged', () async {
      logDeepLFailure('translate', failure, {'x-trace-id': 'abc-123_DEF'});
      await Future<void>.delayed(Duration.zero);
      expect(logged.single, contains('abc-123_DEF'));
      expect(logged.single, contains('429'));
    });

    test('ids that are not plain are left out', () async {
      for (final bad in ['a\nb', 'a b', 'a' * 65, '']) {
        logDeepLFailure('translate', failure, {'x-trace-id': bad});
      }
      await Future<void>.delayed(Duration.zero);
      expect(logged, hasLength(4));
      for (final line in logged) {
        expect(line, isNot(contains('trace')));
        expect(line, isNot(contains('\n')));
      }
    });
  });
}
