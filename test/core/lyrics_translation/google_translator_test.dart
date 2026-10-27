import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/google_translator.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';

import 'loopback_server.dart';

String _fixture(String name) =>
    File('test/core/lyrics_translation/fixtures/$name').readAsStringSync();

final _vi = translationLanguageFor('vi')!;

/// Answers every `q` with `T:<q>` and detected language `en`.
Reply _echo(RecordedRequest request) => Reply(
  200,
  jsonEncode([
    for (final q in request.formQ) ['T:$q', 'en'],
  ]),
);

void main() {
  late HttpClient client;
  late LoopbackServer server;

  setUp(() => client = HttpClient());
  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  GoogleTranslator translator({
    Duration timeout = const Duration(seconds: 5),
  }) => GoogleTranslator(
    client,
    baseUri: server.baseUri,
    requestTimeout: timeout,
  );

  Future<TranslationException> failure(List<String> lines) async {
    try {
      await translator().translate(lines, _vi);
    } on TranslationException catch (e) {
      return e;
    }
    throw StateError('expected a TranslationException');
  }

  test('reports its service and supports every language', () async {
    server = await LoopbackServer.start(_echo);
    expect(translator().service, LyricsTranslationService.google);
    expect(translator().supports(translationLanguageFor('hi')!), isTrue);
  });

  test('120 lines go out as 3 ordered requests with one q per line', () async {
    server = await LoopbackServer.start(_echo);
    final lines = [for (var i = 0; i < 120; i++) 'line $i đ&=+'];
    final result = await translator().translate(lines, _vi);

    expect(server.requests, hasLength(3));
    expect(server.requests.map((r) => r.formQ.length), [50, 50, 20]);
    expect(server.requests.expand((r) => r.formQ).toList(), lines);
    expect(result.texts, [for (final l in lines) 'T:$l']);
    expect(result.detected, everyElement('en'));
    final first = server.requests.first;
    expect(first.method, 'POST');
    expect(first.uri.path, '/translate_a/t');
    expect(first.uri.queryParameters, {
      'client': 'gtx',
      'sl': 'auto',
      'tl': 'vi',
      'dt': 't',
      'ie': 'UTF-8',
      'oe': 'UTF-8',
    });
    expect(first.header('content-type'), contains('x-www-form-urlencoded'));
  });

  test('long lines split by character budget', () async {
    server = await LoopbackServer.start(_echo);
    final lines = [for (var i = 0; i < 5; i++) '$i${'a' * 1500}'];
    final result = await translator().translate(lines, _vi);
    expect(server.requests, hasLength(3)); // 2 + 2 + 1 lines under 4000 chars
    expect(result.texts, hasLength(5));
  });

  test('uses the target Google code', () async {
    server = await LoopbackServer.start(_echo);
    await translator().translate(['x'], translationLanguageFor('zh-Hans')!);
    expect(server.requests.single.uri.queryParameters['tl'], 'zh-CN');
  });

  test('no lines send no request', () async {
    server = await LoopbackServer.start(_echo);
    final result = await translator().translate([], _vi);
    expect(result.texts, isEmpty);
    expect(server.requests, isEmpty);
  });

  test('parses a recorded single-q response', () async {
    server = await LoopbackServer.start(
      (_) => Reply(200, _fixture('google_single_q.json')),
    );
    final result = await translator().translate(['Hello world'], _vi);
    expect(result.texts, ['Xin chào thế giới']);
    expect(result.detected, ['en']);
  });

  test('parses a recorded many-q response', () async {
    server = await LoopbackServer.start(
      (_) => Reply(200, _fixture('google_many_q.json')),
    );
    final result = await translator().translate(['a', 'b', 'c'], _vi);
    expect(result.texts, [
      'Xin chào thế giới',
      'Đêm nay tôi bước đi một mình',
      'Đêm thật yên tĩnh',
    ]);
  });

  test('keeps the detected language of each line', () async {
    server = await LoopbackServer.start(
      (_) => Reply(200, _fixture('google_mixed_languages.json')),
    );
    final result = await translator().translate(['a', 'b', 'c'], _vi);
    expect(result.detected, ['en', 'fr', 'ja']);
  });

  test('accepts a flattened single-q answer and bare strings', () async {
    server = await LoopbackServer.start(
      (_) => const Reply(200, '["Xin chào","en"]'),
    );
    final one = await translator().translate(['Hello'], _vi);
    expect(one.texts, ['Xin chào']);
    expect(one.detected, ['en']);

    server.handler = (_) => const Reply(200, '["a","b","c"]');
    final many = await translator().translate(['1', '2', '3'], _vi);
    expect(many.texts, ['a', 'b', 'c']);
    expect(many.detected, everyElement(isNull));
  });

  test('429 is blocked', () async {
    server = await LoopbackServer.start((_) => const Reply(429, 'slow down'));
    final e = await failure(['x']);
    expect(e.kind, TranslationFailureKind.blocked);
    expect(e.statusCode, 429);
  });

  test('403 and redirects are blocked', () async {
    server = await LoopbackServer.start((_) => const Reply(403, ''));
    expect((await failure(['x'])).kind, TranslationFailureKind.blocked);
    server.handler = (_) =>
        const Reply(302, '', headers: {'location': 'https://example.test/'});
    expect((await failure(['x'])).kind, TranslationFailureKind.blocked);
  });

  test('a redirect is blocked and not followed', () async {
    server = await LoopbackServer.start(
      (_) => const Reply(
        303,
        '',
        headers: {'location': 'http://127.0.0.1:1/elsewhere'},
      ),
    );
    final e = await failure(['x']);
    expect(e.kind, TranslationFailureKind.blocked);
    expect(e.statusCode, 303);
    expect(server.requests, hasLength(1));
  });

  test('an HTML page with status 200 is blocked', () async {
    server = await LoopbackServer.start(
      (_) => const Reply(200, '<html><body>unusual traffic</body></html>'),
    );
    expect((await failure(['x'])).kind, TranslationFailureKind.blocked);
  });

  test('500 is a server failure', () async {
    server = await LoopbackServer.start((_) => const Reply(500, 'boom'));
    final e = await failure(['x']);
    expect(e.kind, TranslationFailureKind.server);
    expect(e.statusCode, 500);
  });

  test('another 4xx is an invalid response', () async {
    server = await LoopbackServer.start((_) => const Reply(400, 'bad'));
    expect((await failure(['x'])).kind, TranslationFailureKind.invalidResponse);
  });

  test('a different number of results is an invalid response', () async {
    server = await LoopbackServer.start(
      (_) => const Reply(200, '[["only one","en"]]'),
    );
    expect(
      (await failure(['a', 'b'])).kind,
      TranslationFailureKind.invalidResponse,
    );
  });

  test('malformed or unexpected JSON is an invalid response', () async {
    server = await LoopbackServer.start((_) => const Reply(200, '{"a":1}'));
    expect((await failure(['x'])).kind, TranslationFailureKind.invalidResponse);
    server.handler = (_) => const Reply(200, '[[1,2]]');
    expect((await failure(['x'])).kind, TranslationFailureKind.invalidResponse);
    server.handler = (_) => const Reply(200, 'not json');
    expect((await failure(['x'])).kind, TranslationFailureKind.invalidResponse);
  });

  test('a reply slower than the timeout is a network failure', () async {
    server = await LoopbackServer.start(
      (_) => const Reply(200, '[]', delay: Duration(milliseconds: 800)),
    );
    try {
      await translator(timeout: const Duration(milliseconds: 100))
          .translate(['x'], _vi);
      fail('expected a failure');
    } on TranslationException catch (e) {
      expect(e.kind, TranslationFailureKind.network);
    }
  });

  test('a failed chunk stops the job without retrying', () async {
    server = await LoopbackServer.start(
      (r) => server.requests.length == 1 ? _echo(r) : const Reply(429, ''),
    );
    final lines = [for (var i = 0; i < 120; i++) 'l$i'];
    await expectLater(
      translator().translate(lines, _vi),
      throwsA(
        isA<TranslationException>().having(
          (e) => e.kind,
          'kind',
          TranslationFailureKind.blocked,
        ),
      ),
    );
    expect(server.requests, hasLength(2)); // no retry, no third chunk
  });

  test('the failure text holds no line text', () async {
    server = await LoopbackServer.start((_) => const Reply(429, 'secret line'));
    final e = await failure(['my private lyric']);
    expect(e.toString(), isNot(contains('private')));
  });
}
