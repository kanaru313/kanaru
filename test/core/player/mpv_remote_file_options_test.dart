import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/mpv_remote_file_options.dart';
import 'package:kanaru/core/sources/source_models.dart';

void main() {
  const url = 'http://127.0.0.1:4000/tok/source-plugin/inst/item1';
  const hlsOptions = [
    ('demuxer-lavf-format', 'hls'),
    ('demuxer-lavf-o', 'protocol_whitelist=[http,tcp,crypto]'),
  ];

  late HandedOutUrls handedOut;
  late List<String> asked;

  setUp(() {
    handedOut = HandedOutUrls()..add(url);
    asked = [];
  });

  Future<List<(String, String)>> optionsFor(
    String path,
    Future<RemoteStreamFormat?> Function(String url) formatOf, {
    Duration wait = const Duration(seconds: 5),
    List<Object>? errors,
  }) => mpvFileOptionsFor(
    path: path,
    handedOut: handedOut,
    formatOf: (url) {
      asked.add(url);
      return formatOf(url);
    },
    wait: wait,
    onError: errors?.add,
  );

  group('mpvRemoteFileOptions', () {
    test('hls widens the whitelist with the brackets mpv needs', () {
      expect(mpvRemoteFileOptions(RemoteStreamFormat.hls), hlsOptions);
    });

    test('progressive needs none', () {
      expect(mpvRemoteFileOptions(RemoteStreamFormat.progressive), isEmpty);
    });
  });

  group('mpvFileOptionsFor', () {
    test('a handed-out URL the proxy says is hls gets the options', () async {
      final options = await optionsFor(
        url,
        (_) async => RemoteStreamFormat.hls,
      );

      expect(options, hlsOptions);
      expect(asked, [url]);
    });

    test('a local file asks nothing and sets nothing', () async {
      final options = await optionsFor(
        '/home/me/music/a.mp3',
        (_) async => RemoteStreamFormat.hls,
      );

      expect(options, isEmpty);
      expect(asked, isEmpty);
    });

    test('a progressive proxy URL sets nothing', () async {
      final options = await optionsFor(
        url,
        (_) async => RemoteStreamFormat.progressive,
      );

      expect(options, isEmpty);
      expect(asked, [url]);
    });

    test('a queued next track counts once its URL was handed out', () async {
      const next = 'http://127.0.0.1:4000/tok/source-plugin/inst/item2';
      expect(
        await optionsFor(next, (_) async => RemoteStreamFormat.hls),
        isEmpty,
      );

      handedOut.add(next);

      expect(
        await optionsFor(next, (_) async => RemoteStreamFormat.hls),
        hlsOptions,
      );
    });

    test('every load asks again and follows the latest answer', () async {
      final answers = [RemoteStreamFormat.progressive, RemoteStreamFormat.hls];

      final first = await optionsFor(url, (_) async => answers[0]);
      final second = await optionsFor(url, (_) async => answers[1]);

      expect(first, isEmpty);
      expect(second, hlsOptions);
      expect(asked, [url, url]);
    });

    test('a null format sets nothing', () async {
      expect(await optionsFor(url, (_) async => null), isEmpty);
    });

    test('a throwing formatOf sets nothing and is reported', () async {
      final errors = <Object>[];

      final options = await optionsFor(
        url,
        (_) async => throw StateError('boom'),
        errors: errors,
      );

      expect(options, isEmpty);
      expect(errors.single, isA<StateError>());
    });

    test('a formatOf that throws at once is also caught', () async {
      final errors = <Object>[];

      final options = await optionsFor(
        url,
        (_) => throw StateError('boom'),
        errors: errors,
      );

      expect(options, isEmpty);
      expect(errors, hasLength(1));
    });

    test('a formatOf slower than the wait sets nothing and reports', () async {
      final never = Completer<RemoteStreamFormat?>();
      final errors = <Object>[];

      final options = await optionsFor(
        url,
        (_) => never.future,
        wait: const Duration(milliseconds: 20),
        errors: errors,
      );

      expect(options, isEmpty);
      expect(errors.single, isA<TimeoutException>());
    });

    test('a path that differs in any character sets nothing', () async {
      for (final path in [
        '$url ',
        ' $url',
        '${url}x',
        url.substring(1),
        url.replaceFirst('127.0.0.1', '127.0.0.2'),
        url.replaceFirst('tok', 'tol'),
        url.replaceFirst('http', 'https'),
        '$url/hls/1/s0.ts',
        '$url?x=1',
        url.toUpperCase(),
        '',
      ]) {
        expect(
          await optionsFor(path, (_) async => RemoteStreamFormat.hls),
          isEmpty,
          reason: path,
        );
      }
      expect(asked, isEmpty);
    });
  });

  group('HandedOutUrls', () {
    test('remembers the last $handedOutUrlLimit URLs', () {
      final urls = HandedOutUrls();
      for (var i = 0; i < handedOutUrlLimit + 1; i++) {
        urls.add('http://127.0.0.1:1/t/source-plugin/i/$i');
      }

      expect(urls.contains('http://127.0.0.1:1/t/source-plugin/i/0'), isFalse);
      expect(urls.contains('http://127.0.0.1:1/t/source-plugin/i/1'), isTrue);
      expect(
        urls.contains(
          'http://127.0.0.1:1/t/source-plugin/i/$handedOutUrlLimit',
        ),
        isTrue,
      );
    });

    test('adding a URL again keeps it among the newest', () {
      final urls = HandedOutUrls()..add('first');
      for (var i = 0; i < handedOutUrlLimit - 1; i++) {
        urls.add('u$i');
      }
      urls
        ..add('first')
        ..add('latest');

      expect(urls.contains('first'), isTrue);
      expect(urls.contains('u0'), isFalse);
    });
  });
}
