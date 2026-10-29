import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lrclib_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_lookups.dart';

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

/// The real LRCLIB client against a loopback server standing in for it.
void main() {
  late LoopbackServer server;
  late RewritingHttpClient client;
  late LyricsHarness h;

  Future<void> setUpWith(
    Reply Function(RecordedRequest) handler, {
    bool autoConsent = true,
  }) async {
    server = await LoopbackServer.start(handler);
    addTearDown(server.close);
    client = RewritingHttpClient(server.baseUri);
    addTearDown(() => client.close(force: true));
    h = await createHarness(
      [LyricsProviderRegistration(LrclibProvider())],
      client: client,
      autoConsent: autoConsent,
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
}
