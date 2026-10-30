import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/candidate_content_hash.dart';
import 'package:kanaru/core/lyrics/online/lrclib_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/run_online_lyrics_lookup.dart';

import '../../lyrics_translation/loopback_server.dart';
import 'bodyless_lyrics_provider.dart';
import 'counting_http_client.dart';
import 'fake_lyrics_provider.dart';
import 'lookup_test_harness.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _words = LyricsBody(syncedLrc: '[00:01.00] fetched words');

void main() {
  late BodylessLyricsProvider fake;
  late LyricsProviderRegistration registration;
  late LyricsHarness h;

  Future<void> setUpWith([BodylessLyricsProvider? provider]) async {
    fake = provider ?? BodylessLyricsProvider();
    registration = LyricsProviderRegistration(fake);
    h = await createHarness([registration]);
  }

  Future<OnlineLyricsLookupResult> run() => runOnlineLyricsLookup(
    registration: registration,
    http: LyricsHttp(registration, CountingHttpClient()),
    db: h.db,
    now: () => h.now,
    target: fakeTarget,
  );

  Future<List<OnlineLyricsRow>> rows() =>
      h.db.watchOnlineLyrics(fakeTarget.cacheKey).first;

  LyricsCandidate bodyless(String id, {Duration? duration}) => fakeCandidate(
    remoteId: id,
    body: null,
    duration: duration ?? const Duration(seconds: 200),
  );

  group('a match that came without lyrics', () {
    setUp(setUpWith);

    test('is fetched once and stored as found', () async {
      fake.searchResult = [bodyless('a')];
      fake.bodies['a'] = _words;

      expect(await run(), OnlineLyricsLookupResult.found);

      expect(fake.fetched, ['a']);
      final row = (await rows()).single;
      expect((row.status, row.remoteId), ('found', 'a'));
      expect(row.syncedText, '[00:01.00] fetched words');
      expect(row.remoteDurationMs, 200000);
    });

    test('an instrumental answer is stored as instrumental', () async {
      fake.searchResult = [bodyless('a')];
      fake.bodies['a'] = const LyricsBody(instrumental: true);

      expect(await run(), OnlineLyricsLookupResult.found);

      expect((await rows()).single.instrumental, isTrue);
    });

    test('with no lyrics goes on with the next good match', () async {
      fake.searchResult = [
        bodyless('a'),
        bodyless('b', duration: const Duration(seconds: 201)),
      ];
      fake.bodies['b'] = _words;

      expect(await run(), OnlineLyricsLookupResult.found);

      expect(fake.fetched, ['a', 'b']);
      expect((await rows()).single.remoteId, 'b');
    });

    test('three fetches without lyrics end as not found', () async {
      fake.searchResult = [
        for (final id in ['a', 'b', 'c', 'd', 'e']) bodyless(id),
      ];

      expect(await run(), OnlineLyricsLookupResult.notFound);

      expect(fake.fetched, ['a', 'b', 'c']);
      expect((await rows()).single.status, 'not_found');
    });

    test('one that does not match the song is never fetched', () async {
      fake.searchResult = [
        fakeCandidate(remoteId: 'far', body: null, artist: 'Someone Else'),
      ];

      expect(await run(), OnlineLyricsLookupResult.notFound);

      expect(fake.fetched, isEmpty);
    });

    test('a fetch failure throws and writes nothing', () async {
      fake.searchResult = [bodyless('a'), bodyless('b')];
      fake.bodies['a'] = const LyricsFetchException(LyricsFetchKind.network);
      fake.bodies['b'] = _words;

      await expectLater(
        run(),
        throwsA(
          isA<LyricsFetchException>().having(
            (e) => e.kind,
            'kind',
            LyricsFetchKind.network,
          ),
        ),
      );

      expect(fake.fetched, ['a']);
      expect(await rows(), isEmpty);
    });

    test('a result with a body is used without any fetch', () async {
      fake.searchResult = [bodyless('a'), fakeCandidate(remoteId: 'b')];

      expect(await run(), OnlineLyricsLookupResult.found);

      expect(fake.fetched, isEmpty);
      expect((await rows()).single.remoteId, 'b');
    });

    test('an exact record without lyrics is fetched too', () async {
      fake.lookupResult = bodyless('x');
      fake.bodies['x'] = _words;

      expect(await run(), OnlineLyricsLookupResult.found);

      expect(fake.fetched, ['x']);
      expect((await rows()).single.remoteId, 'x');
    });

    test('fetched text is cleaned before it is stored', () async {
      fake.searchResult = [bodyless('a')];
      fake.bodies['a'] = const LyricsBody(
        syncedLrc: '[00:01.00] one\r\n[00:02.00] two\x07',
      );

      await run();

      expect(
        (await rows()).single.syncedText,
        '[00:01.00] one\n[00:02.00] two',
      );
    });
  });

  group('reject by text', () {
    setUp(setUpWith);

    test('a fetched text equal to a rejected one is skipped', () async {
      final rejectedText = fakeCandidate(
        remoteId: 'old',
        body: const LyricsBody(syncedLrc: '[00:01.00] same words'),
      );
      await h.db.rejectOnlineLyrics(
        cacheKey: fakeTarget.cacheKey,
        providerId: 'other',
        remoteId: 'old',
        contentHash: candidateContentHash(rejectedText),
        trackKey: fakeTarget.trackKey,
        now: 1,
      );
      fake.searchResult = [
        bodyless('a'),
        bodyless('b', duration: const Duration(seconds: 201)),
      ];
      fake.bodies['a'] = const LyricsBody(syncedLrc: '[00:01.00] same words');
      fake.bodies['b'] = _words;

      expect(await run(), OnlineLyricsLookupResult.found);

      expect(fake.fetched, ['a', 'b']);
      expect((await rows()).single.remoteId, 'b');
    });
  });

  group('bonus synced search of a plain exact record', () {
    setUp(setUpWith);

    test('a best match without a body counts after its fetch', () async {
      fake.lookupResult = fakeCandidate(
        remoteId: 'plain',
        body: const LyricsBody(plain: 'plain words'),
      );
      fake.searchResult = [bodyless('s')];
      fake.bodies['s'] = _words;

      await run();

      expect(fake.fetched, ['s']);
      expect((await rows()).single.remoteId, 's');
    });

    test('a fetched body without synced text keeps the plain one', () async {
      fake.lookupResult = fakeCandidate(
        remoteId: 'plain',
        body: const LyricsBody(plain: 'plain words'),
      );
      fake.searchResult = [bodyless('s')];
      fake.bodies['s'] = const LyricsBody(plain: 'other plain');

      await run();

      expect((await rows()).single.remoteId, 'plain');
    });

    test('a failed fetch keeps the plain one', () async {
      fake.lookupResult = fakeCandidate(
        remoteId: 'plain',
        body: const LyricsBody(plain: 'plain words'),
      );
      fake.searchResult = [bodyless('s')];
      fake.bodies['s'] = const LyricsFetchException(LyricsFetchKind.server);

      await run();

      expect((await rows()).single.remoteId, 'plain');
    });
  });

  group('host checks', () {
    setUp(setUpWith);

    test('a list of nothing valid throws and writes nothing', () async {
      fake.searchResult = [fakeCandidate(remoteId: '', body: null)];

      await expectLater(
        run(),
        throwsA(
          isA<LyricsFetchException>().having(
            (e) => e.kind,
            'kind',
            LyricsFetchKind.invalidResponse,
          ),
        ),
      );

      expect(await rows(), isEmpty);
    });

    test('an invalid candidate is dropped, the others are used', () async {
      fake.searchResult = [
        fakeCandidate(remoteId: '', body: null),
        fakeCandidate(remoteId: 'ok'),
      ];

      expect(await run(), OnlineLyricsLookupResult.found);
      expect((await rows()).single.remoteId, 'ok');
    });

    test('the provider id is the registered one', () async {
      fake.searchResult = [fakeCandidate(providerId: 'liar', remoteId: 'ok')];

      await run();

      expect((await rows()).single.providerId, 'fake');
    });

    test('an invalid exact record throws', () async {
      fake.lookupResult = fakeCandidate(remoteId: 'x', title: '  ');

      await expectLater(
        run(),
        throwsA(
          isA<LyricsFetchException>().having(
            (e) => e.kind,
            'kind',
            LyricsFetchKind.invalidResponse,
          ),
        ),
      );
    });
  });

  group('LRCLIB', () {
    late LoopbackServer server;

    Map<String, Object?> record(int id) => {
      'id': id,
      'trackName': 'Song',
      'artistName': 'Artist',
      'albumName': 'Alb',
      'duration': 200,
      'instrumental': false,
      'syncedLyrics': '[00:01.00] hi\r\n[00:02.00] there',
      'plainLyrics': 'hi\nthere',
    };

    Future<void> lrclib(Reply Function(RecordedRequest) handler) async {
      server = await LoopbackServer.start(handler);
      addTearDown(server.close);
      final client = RewritingHttpClient(server.baseUri);
      addTearDown(() => client.close(force: true));
      registration = LyricsProviderRegistration(LrclibProvider());
      h = await createHarness([registration], client: client);
    }

    Future<OnlineLyricsLookupResult> runLrclib() => runOnlineLyricsLookup(
      registration: registration,
      http: LyricsHttp.forTesting(
        client: RewritingHttpClient(server.baseUri),
        hosts: registration.hosts,
      ),
      db: h.db,
      now: () => h.now,
      target: fakeTarget,
    );

    test('an exact hit is one request and the text is kept', () async {
      await lrclib((_) => Reply(200, jsonEncode(record(5)), headers: _json));

      expect(await runLrclib(), OnlineLyricsLookupResult.found);

      expect(server.requests.map((r) => r.uri.path), ['/api/get']);
      final row = (await rows()).single;
      expect(row.syncedText, '[00:01.00] hi\n[00:02.00] there');
      expect(row.plainText, 'hi\nthere');
    });

    test('a search hit is two requests and no fetch', () async {
      await lrclib(
        (r) => r.uri.path == '/api/get'
            ? const Reply(
                404,
                '{"code":404,"name":"TrackNotFound","message":"x"}',
                headers: _json,
              )
            : Reply(200, jsonEncode([record(9)]), headers: _json),
      );

      expect(await runLrclib(), OnlineLyricsLookupResult.found);

      expect(server.requests.map((r) => r.uri.path), [
        '/api/get',
        '/api/search',
      ]);
      expect((await rows()).single.remoteId, '9');
    });
  });
}
