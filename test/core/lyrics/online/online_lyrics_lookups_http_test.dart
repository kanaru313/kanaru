import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lrclib_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_backoff.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_http_factory.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_lookups.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';

import '../../lyrics_translation/loopback_server.dart';
import 'lookup_test_harness.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _notFound = Reply(
  404,
  '{"code":404,"name":"TrackNotFound","message":"x"}',
  headers: _json,
);

Map<String, Object?> _record(int id) => {
  'id': id,
  'trackName': 'Song',
  'artistName': 'Artist',
  'albumName': 'Alb',
  'duration': 200,
  'instrumental': false,
  'syncedLyrics': '[00:01.00] hi',
  'plainLyrics': 'hi',
};

/// Sends `/api/search` nowhere when [failSearch] is set: the connection fails.
class _FlakyClient extends RewritingHttpClient {
  _FlakyClient(super.base);

  bool failSearch = false;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      failSearch && url.path == '/api/search'
      ? Future.error(const SocketException('search is down'))
      : super.openUrl(method, url);
}

/// The real LRCLIB client against a loopback server standing in for it.
void main() {
  late LoopbackServer server;
  late _FlakyClient client;
  late LyricsHarness h;
  final sleeps = <Duration>[];

  /// Runs before each wait between two sends of a busy answer.
  Future<void> Function()? onSleep;

  Future<void> setUpWith(
    Reply Function(RecordedRequest) handler, {
    bool autoConsent = true,
    List<Override> overrides = const [],
  }) async {
    sleeps.clear();
    onSleep = null;
    server = await LoopbackServer.start(handler);
    addTearDown(server.close);
    client = _FlakyClient(server.baseUri);
    addTearDown(() => client.close(force: true));
    h = await createHarness(
      [LyricsProviderRegistration(LrclibProvider())],
      client: client,
      autoConsent: autoConsent,
      overrides: [
        lyricsRetrySleepProvider.overrideWithValue((wait) async {
          sleeps.add(wait);
          await onSleep?.call();
        }),
        onlineLyricsDebounceProvider.overrideWithValue(Duration.zero),
        ...overrides,
      ],
    );
  }

  Future<int> rowCount() async =>
      (await h.db.watchOnlineLyrics(fakeTarget.cacheKey).first).length;

  test('200 from /api/get stores a found row', () async {
    await setUpWith((_) => Reply(200, jsonEncode(_record(5)), headers: _json));

    await h.lookups.start(fakeTarget, auto: true);

    final row =
        (await h.db.watchOnlineLyrics(fakeTarget.cacheKey).first).single;
    expect(
      (row.providerId, row.status, row.remoteId),
      ('lrclib', 'found', '5'),
    );
    expect(server.requests.single.uri.path, '/api/get');
  });

  test('TrackNotFound then an empty search stores not_found', () async {
    await setUpWith(
      (r) => r.uri.path == '/api/get'
          ? _notFound
          : const Reply(200, '[]', headers: _json),
    );

    await h.lookups.start(fakeTarget, auto: true);

    final row =
        (await h.db.watchOnlineLyrics(fakeTarget.cacheKey).first).single;
    expect(row.status, 'not_found');
    expect(server.requests.map((r) => r.uri.path), ['/api/get', '/api/search']);
  });

  test('TrackNotFound then a search hit stores the gated best', () async {
    await setUpWith(
      (r) => r.uri.path == '/api/get'
          ? _notFound
          : Reply(200, jsonEncode([_record(9)]), headers: _json),
    );

    await h.lookups.start(fakeTarget, auto: true);

    final row =
        (await h.db.watchOnlineLyrics(fakeTarget.cacheKey).first).single;
    expect((row.status, row.remoteId), ('found', '9'));
  });

  test('a search hit filed under the other artist is found', () async {
    final target = LyricsTarget.fromFields(
      uri: '/music/duo.flac',
      title: 'Song',
      artist: 'Ngân Ngân, Châu Khải Phong',
      album: 'Alb',
      duration: const Duration(seconds: 200),
    );
    await setUpWith(
      (r) => r.uri.path == '/api/get'
          ? _notFound
          : Reply(
              200,
              jsonEncode([
                {..._record(9), 'artistName': 'Chau Khai Phong'},
              ]),
              headers: _json,
            ),
    );

    await h.lookups.start(target, auto: true);

    final row = (await h.db.watchOnlineLyrics(target.cacheKey).first).single;
    expect((row.status, row.remoteId), ('found', '9'));
    final get = server.requests.first.uri;
    expect(get.path, '/api/get');
    expect(get.queryParameters['artist_name'], 'Ngân Ngân');
    final search = server.requests.last.uri;
    expect(search.path, '/api/search');
    expect(search.queryParameters, {'track_name': 'Song'});
    expect(server.requests, hasLength(2));
  });

  final failures = <String, Reply>{
    '404 with an HTML body': const Reply(
      404,
      '<html>captive portal</html>',
      headers: {'content-type': 'text/html'},
    ),
    '403': const Reply(403, 'no', headers: _json),
    '302 redirect': const Reply(302, '', headers: {'location': '/login'}),
    '200 with HTML': const Reply(
      200,
      '<html></html>',
      headers: {'content-type': 'text/html'},
    ),
  };
  failures.forEach((name, reply) {
    test('$name: no row, error state, backoff, no search', () async {
      await setUpWith((_) => reply);

      await h.lookups.start(fakeTarget, auto: true);

      expect(await rowCount(), 0);
      expect(h.container.read(onlineLyricsLookupsProvider), {
        fakeTarget.cacheKey: isA<LookupFailed>(),
      });
      expect(h.backoff.isBlocked, isTrue);
      expect(server.requests, hasLength(1));
    });
  });

  test('429 with Retry-After 120 blocks for at least 120 s', () async {
    await setUpWith(
      (_) => const Reply(429, '', headers: {'retry-after': '120'}),
    );

    await h.lookups.start(fakeTarget, auto: true);

    expect(await rowCount(), 0);
    h.now = h.now.add(const Duration(seconds: 119));
    expect(h.backoff.isBlocked, isTrue);
  });

  test('without consent no socket is opened', () async {
    await setUpWith((_) => _notFound, autoConsent: false);

    await h.lookups.start(fakeTarget, auto: true);

    expect(client.opened, 0);
    expect(server.requests, isEmpty);
  });

  group('synced preferred over a plain exact hit', () {
    Map<String, Object?> plain(int id) => {
      ..._record(id),
      'syncedLyrics': null,
      'plainLyrics': 'hello there',
    };

    test('a synced search match replaces the plain exact hit', () async {
      await setUpWith(
        (r) => r.uri.path == '/api/get'
            ? Reply(200, jsonEncode(plain(1)), headers: _json)
            : Reply(200, jsonEncode([plain(1), _record(2)]), headers: _json),
      );

      await h.lookups.start(fakeTarget, auto: true);

      final row =
          (await h.db.watchOnlineLyrics(fakeTarget.cacheKey).first).single;
      expect((row.status, row.remoteId), ('found', '2'));
      expect(row.syncedText, isNotNull);
      expect(server.requests.last.uri.path, '/api/search');
      expect(server.requests.last.uri.queryParameters, {
        'track_name': 'Song',
        'artist_name': 'Artist',
      });
      expect(server.requests, hasLength(2));
      expect(
        server.requests.first.uri.queryParameters.containsKey('album_name'),
        isFalse,
      );
    });

    test('without a synced match the plain exact hit is kept', () async {
      await setUpWith(
        (r) => r.uri.path == '/api/get'
            ? Reply(200, jsonEncode(plain(1)), headers: _json)
            : Reply(200, jsonEncode([plain(1), plain(3)]), headers: _json),
      );

      await h.lookups.start(fakeTarget, auto: true);

      final row =
          (await h.db.watchOnlineLyrics(fakeTarget.cacheKey).first).single;
      expect((row.status, row.remoteId, row.syncedText), ('found', '1', null));
      expect(server.requests, hasLength(2));
      expect(server.requests.last.uri.path, '/api/search');
      expect(server.requests.last.uri.queryParameters, {
        'track_name': 'Song',
        'artist_name': 'Artist',
      });
    });

    test('a synced exact hit needs no search', () async {
      await setUpWith(
        (_) => Reply(200, jsonEncode(_record(5)), headers: _json),
      );

      await h.lookups.start(fakeTarget, auto: true);

      expect(server.requests, hasLength(1));
    });

    test('a 503 on the extra search keeps the plain exact hit', () async {
      await setUpWith(
        (r) => r.uri.path == '/api/get'
            ? Reply(200, jsonEncode(plain(1)), headers: _json)
            : const Reply(503, '{}', headers: _json),
      );

      await h.lookups.start(fakeTarget, auto: true);

      final row =
          (await h.db.watchOnlineLyrics(fakeTarget.cacheKey).first).single;
      expect((row.status, row.remoteId), ('found', '1'));
      expect(h.backoff.isBlocked, isFalse);
      expect(h.container.read(onlineLyricsLookupsProvider), isEmpty);
    });

    test('a network failure on the extra search keeps the hit', () async {
      await setUpWith((_) => Reply(200, jsonEncode(plain(1)), headers: _json));
      client.failSearch = true;

      await h.lookups.start(fakeTarget, auto: true);

      final row =
          (await h.db.watchOnlineLyrics(fakeTarget.cacheKey).first).single;
      expect((row.status, row.remoteId), ('found', '1'));
      expect(h.backoff.isBlocked, isFalse);
    });

    test(
      'consent withdrawn while a synced answer arrives stores nothing',
      () async {
        final registration = LyricsProviderRegistration(LrclibProvider());
        final acknowledged = {
          registration.consentKey,
          registration.autoConsentKey,
        };
        await setUpWith(
          (_) {
            acknowledged.clear();
            return Reply(200, jsonEncode(_record(5)), headers: _json);
          },
          overrides: [
            onlineLyricsHttpFactoryProvider.overrideWith(
              (ref) => OnlineLyricsHttpFactory(
                acknowledged: () => acknowledged,
                client: () => client,
              ),
            ),
          ],
        );

        await h.lookups.start(fakeTarget, auto: true);

        expect(await rowCount(), 0);
        expect(h.backoff.isBlocked, isFalse);
        expect(h.container.read(onlineLyricsLookupsProvider), isEmpty);
      },
    );

    test('consent withdrawn between the two requests stores nothing', () async {
      final acknowledged = <String>{};
      final registration = LyricsProviderRegistration(LrclibProvider());
      acknowledged.addAll([
        registration.consentKey,
        registration.autoConsentKey,
      ]);
      await setUpWith(
        (r) {
          if (r.uri.path == '/api/get') {
            // Consent is withdrawn right after the first answer.
            Future<void>.microtask(acknowledged.clear);
            return Reply(200, jsonEncode(plain(1)), headers: _json);
          }
          return Reply(200, jsonEncode([_record(2)]), headers: _json);
        },
        overrides: [
          onlineLyricsHttpFactoryProvider.overrideWith(
            (ref) => OnlineLyricsHttpFactory(
              acknowledged: () => acknowledged,
              client: () => client,
            ),
          ),
        ],
      );

      await h.lookups.start(fakeTarget, auto: true);

      expect(server.requests.map((r) => r.uri.path), ['/api/get']);
      expect(await rowCount(), 0);
      expect(h.backoff.isBlocked, isFalse);
    });
  });

  group('busy answers', () {
    Reply busy([String? retryAfter]) => Reply(
      503,
      '{"name":"ServerOverloaded"}',
      headers: {..._json, 'retry-after': ?retryAfter},
    );

    LookupState? failed() =>
        h.container.read(onlineLyricsLookupsProvider)[fakeTarget.cacheKey];

    test('503 then 200 stores a found row without a backoff', () async {
      var calls = 0;
      await setUpWith(
        (_) => ++calls == 1
            ? busy('1')
            : Reply(200, jsonEncode(_record(5)), headers: _json),
      );

      await h.lookups.start(fakeTarget, auto: true);

      expect(server.requests, hasLength(2));
      expect(sleeps, [const Duration(seconds: 1)]);
      expect((await rowCount()), 1);
      expect(failed(), isNull);
      expect(h.backoff.isBlocked, isFalse);
    });

    test('503 three times fails as rateLimited with one backoff', () async {
      await setUpWith((_) => busy('1'));

      await h.lookups.start(fakeTarget, auto: true);

      expect(server.requests, hasLength(3));
      expect(sleeps, hasLength(2));
      expect(await rowCount(), 0);
      expect((failed() as LookupFailed).kind, LyricsFetchKind.rateLimited);
      h.now = h.now.add(const Duration(seconds: 59));
      expect(h.backoff.isBlocked, isTrue);
    });

    test('429 without Retry-After is sent once', () async {
      await setUpWith((_) => const Reply(429, '', headers: _json));

      await h.lookups.start(fakeTarget, auto: true);

      expect(server.requests, hasLength(1));
      expect(sleeps, isEmpty);
      expect((failed() as LookupFailed).kind, LyricsFetchKind.rateLimited);
    });

    test('Retry-After 30 is not waited out and sets the backoff', () async {
      await setUpWith((_) => busy('30'));

      await h.lookups.start(fakeTarget, auto: true);

      expect(server.requests, hasLength(1));
      expect(sleeps, isEmpty);
      h.now = h.now.add(const Duration(seconds: 59));
      expect(h.backoff.isBlocked, isTrue);
    });

    test('an abandoned lookup sends nothing after the wait', () async {
      await setUpWith((_) => busy('1'));
      var abandoned = false;
      onSleep = () async => abandoned = true;

      await h.lookups.start(fakeTarget, auto: true, abandoned: () => abandoned);

      expect(server.requests, hasLength(1));
      expect(failed(), isNull);
      expect(h.backoff.isBlocked, isFalse);
    });

    test('the song changing during the wait sends nothing more', () async {
      await setUpWith((_) => busy('1'));
      final sub = h.container.listen(
        autoLyricsLookupProvider(fakeTarget),
        (_, _) {},
      );
      // The lookup ends by leaving the running state (no failure is set).
      final ended = Completer<void>();
      h.container.listen(onlineLyricsLookupsProvider, (_, next) {
        if (next.isEmpty && !ended.isCompleted) ended.complete();
      });
      // The song changes (the provider is disposed) while the lookup waits.
      onSleep = () async {
        sub.close();
        await h.container.pump();
      };

      await ended.future.timeout(const Duration(seconds: 5));

      expect(server.requests, hasLength(1));
      expect(failed(), isNull);
      expect(h.backoff.isBlocked, isFalse);
    });

    test('the song coming back during the wait keeps the lookup', () async {
      var calls = 0;
      await setUpWith(
        (_) => ++calls == 1
            ? busy('1')
            : Reply(200, jsonEncode(_record(5)), headers: _json),
      );
      final first = h.container.listen(
        autoLyricsLookupProvider(fakeTarget),
        (_, _) {},
      );
      final back = Completer<void>();
      onSleep = () async {
        // Skipped away and back: the first watcher is disposed, a new one
        // starts the same song's lookup and joins the one that waits.
        first.close();
        await h.container.pump();
        final second = h.container.listen(
          autoLyricsLookupProvider(fakeTarget),
          (_, _) {},
        );
        addTearDown(second.close);
        await Future<void>.delayed(Duration.zero);
        back.complete();
      };

      await back.future;
      await h.container.read(autoLyricsLookupProvider(fakeTarget).future);

      expect(server.requests, hasLength(2));
      expect(await rowCount(), 1);
    });

    test('a manual lookup joining a waiting auto one is not dropped', () async {
      var calls = 0;
      await setUpWith(
        (_) => ++calls == 1
            ? busy('1')
            : Reply(200, jsonEncode(_record(5)), headers: _json),
      );
      final auto = h.container.listen(
        autoLyricsLookupProvider(fakeTarget),
        (_, _) {},
      );
      final manual = Completer<Future<void>>();
      onSleep = () async {
        // Retry pressed while the auto lookup waits, then the song changes.
        manual.complete(h.lookups.start(fakeTarget, auto: false));
        auto.close();
        await h.container.pump();
      };

      await (await manual.future);

      expect(server.requests, hasLength(2));
      expect(await rowCount(), 1);
      expect(failed(), isNull);
    });
  });
}
