import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/deepl_api.dart';
import 'package:kanaru/core/lyrics_translation/deepl_translator.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';

import 'loopback_server.dart';

const _key = '00000000-0000-0000-0000-000000000000:fx';
final _vi = translationLanguageFor('vi')!;

/// A target DeepL cannot translate into.
const _noDeepL = TranslationLanguage('xx', 'xx', 'xx');

String _fixture(String name) =>
    File('test/core/lyrics_translation/fixtures/$name').readAsStringSync();

/// Answers each text with `T:<text>`, detected language `EN`.
Reply _echo(RecordedRequest request) => Reply(
  200,
  jsonEncode({
    'translations': [
      for (final t in request.json['text'] as List)
        {'detected_source_language': 'EN', 'text': 'T:$t'},
    ],
  }),
);

void main() {
  late HttpClient client;
  late LoopbackServer server;

  setUp(() => client = HttpClient());
  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  DeepLTranslator translator([String key = _key]) =>
      DeepLTranslator(client, key, baseUri: server.baseUri);

  Future<TranslationException> failure() async {
    try {
      await translator().translate(['my private lyric'], _vi);
    } on TranslationException catch (e) {
      return e;
    }
    throw StateError('expected a TranslationException');
  }

  group('host and capabilities', () {
    test('free keys use the free host, others the paid one', () async {
      server = await LoopbackServer.start(_echo);
      expect(deeplBaseFor(_key).host, 'api-free.deepl.com');
      expect(
        deeplBaseFor('00000000-0000-0000-0000-000000000000').host,
        'api.deepl.com',
      );
    });

    test('supports only languages with a DeepL code', () async {
      server = await LoopbackServer.start(_echo);
      expect(translator().service, LyricsTranslationService.deepl);
      expect(translator().supports(_vi), isTrue);
      expect(translator().supports(_noDeepL), isFalse);
    });

    test('an unsupported target fails before any request', () async {
      server = await LoopbackServer.start(_echo);
      await expectLater(
        translator().translate(['x'], _noDeepL),
        throwsA(
          isA<TranslationException>().having(
            (e) => e.kind,
            'kind',
            TranslationFailureKind.unsupportedLanguage,
          ),
        ),
      );
      expect(server.requests, isEmpty);
    });
  });

  group('request', () {
    test(
      'sets auth, JSON body, split_sentences 0 and a bounded context',
      () async {
        server = await LoopbackServer.start(_echo);
        final lines = [for (var i = 0; i < 20; i++) '${'word ' * 40}$i'];
        await translator().translate(lines, _vi);

        final seen = server.requests.single;
        expect(seen.method, 'POST');
        expect(seen.uri.path, '/v2/translate');
        expect(seen.header('authorization'), 'DeepL-Auth-Key $_key');
        expect(seen.header('content-type'), contains('application/json'));
        final body = seen.json;
        expect(body['text'], lines);
        expect(body['target_lang'], 'VI');
        expect(body['split_sentences'], '0');
        expect(body['preserve_formatting'], isTrue);
        final context = body['context'] as String;
        expect(context, isNotEmpty);
        expect(context.length, lessThanOrEqualTo(4000));
        expect(context, startsWith(lines.first));
      },
    );

    test('an explicit context replaces the joined lines', () async {
      server = await LoopbackServer.start(_echo);
      await translator().translate(['a'], _vi, context: 'whole song');
      expect(server.requests.single.json['context'], 'whole song');
    });

    test('the context is cut without splitting a surrogate pair', () async {
      server = await LoopbackServer.start(_echo);
      await translator().translate(
        ['a'],
        _vi,
        context: '${'a' * 3999}\u{1F600}',
      );
      expect((server.requests.single.json['context'] as String).length, 3999);
    });

    test('60 texts go out as 2 requests of at most 50', () async {
      server = await LoopbackServer.start(_echo);
      final lines = [for (var i = 0; i < 60; i++) 'line $i'];
      final result = await translator().translate(lines, _vi);
      expect(server.requests, hasLength(2));
      expect(server.requests.map((r) => (r.json['text'] as List).length), [
        50,
        10,
      ]);
      expect(result.texts, [for (final l in lines) 'T:$l']);
    });

    test('large lines split so every body stays under 100 KiB', () async {
      server = await LoopbackServer.start(_echo);
      final lines = [for (var i = 0; i < 12; i++) '$i${'é' * 4000}'];
      final result = await translator().translate(lines, _vi);
      expect(server.requests.length, greaterThan(1));
      for (final r in server.requests) {
        expect(utf8.encode(r.body).length, lessThanOrEqualTo(100 * 1024));
      }
      expect(result.texts, hasLength(12));
    });

    test('no lines send no request', () async {
      server = await LoopbackServer.start(_echo);
      await translator().translate([], _vi);
      expect(server.requests, isEmpty);
    });
  });

  group('response', () {
    test('lower-cases the detected language', () async {
      server = await LoopbackServer.start(
        (_) => Reply(200, _fixture('deepl_translate.json')),
      );
      final result = await translator().translate(['a', 'b'], _vi);
      expect(result.texts, ['Xin chào thế giới', 'Đêm thật yên tĩnh']);
      expect(result.detected, ['en', 'fr']);
    });

    test('malformed or short answers are invalid responses', () async {
      server = await LoopbackServer.start((_) => const Reply(200, '{oops'));
      expect((await failure()).kind, TranslationFailureKind.invalidResponse);
      server.handler = (_) => const Reply(200, '{"translations":[]}');
      expect((await failure()).kind, TranslationFailureKind.invalidResponse);
      server.handler = (_) => const Reply(200, '{"translations":[{"x":1}]}');
      expect((await failure()).kind, TranslationFailureKind.invalidResponse);
      server.handler = (_) => const Reply(200, '[]');
      expect((await failure()).kind, TranslationFailureKind.invalidResponse);
    });
  });

  group('status mapping', () {
    const cases = {
      401: TranslationFailureKind.badKey,
      403: TranslationFailureKind.badKey,
      456: TranslationFailureKind.quotaExceeded,
      429: TranslationFailureKind.rateLimited,
      529: TranslationFailureKind.rateLimited,
      413: TranslationFailureKind.invalidResponse,
      500: TranslationFailureKind.server,
      503: TranslationFailureKind.server,
      400: TranslationFailureKind.invalidResponse,
    };
    cases.forEach((status, kind) {
      test('HTTP $status is ${kind.name}', () async {
        server = await LoopbackServer.start(
          (_) => Reply(status, '', headers: {'X-Trace-ID': 'trace-1'}),
        );
        final e = await failure();
        expect(e.kind, kind);
        expect(e.statusCode, status);
        expect(server.requests, hasLength(1)); // no retry
      });
    });

    test('a failed chunk stops the job', () async {
      server = await LoopbackServer.start(
        (r) => server.requests.length == 1 ? _echo(r) : const Reply(456, ''),
      );
      await expectLater(
        translator().translate([for (var i = 0; i < 60; i++) 'l$i'], _vi),
        throwsA(
          isA<TranslationException>().having(
            (e) => e.kind,
            'kind',
            TranslationFailureKind.quotaExceeded,
          ),
        ),
      );
      expect(server.requests, hasLength(2));
    });

    test('a slow reply is a network failure', () async {
      server = await LoopbackServer.start(
        (_) => const Reply(200, '', delay: Duration(milliseconds: 800)),
      );
      final slow = DeepLTranslator(
        client,
        _key,
        baseUri: server.baseUri,
        requestTimeout: const Duration(milliseconds: 100),
      );
      await expectLater(
        slow.translate(['x'], _vi),
        throwsA(
          isA<TranslationException>().having(
            (e) => e.kind,
            'kind',
            TranslationFailureKind.network,
          ),
        ),
      );
    });
  });

  group('key hygiene', () {
    test('a key with stray whitespace is trimmed and works', () async {
      server = await LoopbackServer.start(_echo);
      await translator(' $_key\n').translate(['x'], _vi);
      expect(
        server.requests.single.header('authorization'),
        'DeepL-Auth-Key $_key',
      );
    });

    test('normalizeDeepLKey trims and rejects bad keys', () {
      expect(normalizeDeepLKey('  $_key \t'), _key);
      for (final bad in [
        '',
        'short',
        'a' * 129,
        '${'a' * 20}\n${'b' * 20}',
        '${'a' * 20} ${'b' * 20}',
        '${'a' * 20}\u0000',
        '${'a' * 20}é',
      ]) {
        expect(
          () => normalizeDeepLKey(bad),
          throwsA(
            isA<TranslationException>().having(
              (e) => e.kind,
              'kind',
              TranslationFailureKind.badKey,
            ),
          ),
          reason: 'key of length ${bad.length}',
        );
      }
    });

    test(
      'an inner newline is badKey, sends nothing and leaks nothing',
      () async {
        server = await LoopbackServer.start(_echo);
        const bad = 'SECRETPART-aaaaaaaaaa\nbbbbbbbbbb:fx';
        Object? caught;
        try {
          await translator(bad).translate(['x'], _vi);
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<TranslationException>());
        expect(
          (caught! as TranslationException).kind,
          TranslationFailureKind.badKey,
        );
        expect(caught.toString(), isNot(contains('SECRETPART')));
        expect(server.requests, isEmpty);
      },
    );
  });

  test('the failure text holds neither key nor line text', () async {
    server = await LoopbackServer.start((_) => const Reply(403, ''));
    final text = (await failure()).toString();
    expect(text, isNot(contains(_key)));
    expect(text, isNot(contains('private')));
  });
}
