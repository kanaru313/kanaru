import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lrclib_provider.dart';
import 'package:kanaru/core/lyrics/online/lrclib_record.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';

import '../../lyrics_translation/loopback_server.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, Object?> _record({
  int id = 1,
  Object? track = 'Song',
  Object? artist = 'X',
  Object? album = 'Alb',
  Object? duration = 200,
  Object? instrumental = false,
  Object? synced = '[00:01.00] hi',
  Object? plain = 'hi',
}) => {
  'id': id,
  'trackName': track,
  'artistName': artist,
  'albumName': album,
  'duration': duration,
  'instrumental': instrumental,
  'syncedLyrics': synced,
  'plainLyrics': plain,
};

Reply _ok(Object? body) => Reply(200, jsonEncode(body), headers: _json);

Future<LyricsFetchException> _failure(Future<Object?> call) async {
  try {
    await call;
  } on LyricsFetchException catch (e) {
    return e;
  }
  throw StateError('expected a LyricsFetchException');
}

void main() {
  late HttpClient client;
  late LoopbackServer server;
  late LrclibProvider provider;
  late LyricsHttp http;

  setUp(() async {
    client = HttpClient();
    server = await LoopbackServer.start((_) => _ok(_record()));
    provider = LrclibProvider(baseUri: server.baseUri);
    http = LyricsHttp.forTesting(client: client, hosts: provider.hosts);
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  const query = LyricsQuery(
    title: 'Song',
    artist: 'X',
    album: 'Alb',
    duration: Duration(seconds: 200),
  );

  group('lookup', () {
    test('200 gives a candidate and sends the exact fields', () async {
      final c = (await provider.lookup(query, http))!;
      expect(c.providerId, 'lrclib');
      expect(c.remoteId, '1');
      expect((c.title, c.artist, c.album), ('Song', 'X', 'Alb'));
      expect(c.duration, const Duration(seconds: 200));
      expect(c.body!.syncedLrc, '[00:01.00] hi');
      expect(c.body!.plain, 'hi');
      final request = server.requests.single;
      expect(request.uri.path, '/api/get');
      expect(request.uri.queryParameters, {
        'track_name': 'Song',
        'artist_name': 'X',
        'album_name': 'Alb',
        'duration': '200',
      });
    });

    test('sends the primary artist of a multi-artist tag', () async {
      await provider.lookup(
        const LyricsQuery(
          title: 'S',
          artist: 'A; B',
          duration: Duration(seconds: 90),
        ),
        http,
      );
      final sent = server.requests.single.uri.queryParameters;
      expect(sent['artist_name'], 'A');
      expect(sent.containsKey('album_name'), isFalse);
    });

    test('rounds the duration and omits it outside 1..3600 s', () async {
      Future<String?> sentFor(Duration d) async {
        server.requests.clear();
        await provider.lookup(
          LyricsQuery(title: 'S', artist: 'A', duration: d),
          http,
        );
        return server.requests.single.uri.queryParameters['duration'];
      }

      expect(await sentFor(const Duration(milliseconds: 200400)), '200');
      expect(await sentFor(const Duration(milliseconds: 200500)), '201');
      expect(await sentFor(const Duration(milliseconds: 1000)), '1');
      expect(await sentFor(const Duration(milliseconds: 400)), isNull);
      expect(await sentFor(const Duration(seconds: 3600)), '3600');
      expect(await sentFor(const Duration(seconds: 3601)), isNull);
    });

    test('no title or primary artist throws and sends nothing', () async {
      for (final q in const [
        LyricsQuery(title: 'S'),
        LyricsQuery(artist: 'A'),
        LyricsQuery(title: 'S', artist: ';'),
      ]) {
        expect(provider.lookup(q, http), throwsArgumentError);
      }
      expect(server.requests, isEmpty);
    });

    test('404 TrackNotFound JSON is the only not-found', () async {
      server.handler = (_) => const Reply(
        404,
        '{"code":404,"name":"TrackNotFound","message":"x"}',
        headers: _json,
      );
      expect(await provider.lookup(query, http), isNull);
    });

    test('an instrumental record keeps the flag', () async {
      server.handler = (_) =>
          _ok(_record(instrumental: true, synced: null, plain: null));
      final body = (await provider.lookup(query, http))!.body!;
      expect(body.instrumental, isTrue);
      expect(body.hasLyrics, isFalse);
    });

    final bad = <String, Reply>{
      '404 html': const Reply(
        404,
        '<html>portal</html>',
        headers: {'content-type': 'text/html'},
      ),
      '404 json of another name': const Reply(
        404,
        '{"name":"Other"}',
        headers: _json,
      ),
      '200 html': const Reply(
        200,
        '<html></html>',
        headers: {'content-type': 'text/html'},
      ),
      '200 malformed json': const Reply(200, '{', headers: _json),
      '200 wrong shape': const Reply(200, '[]', headers: _json),
      '200 id missing': Reply(
        200,
        '{"trackName":"a","artistName":"b"}',
        headers: _json,
      ),
    };
    bad.forEach((name, reply) {
      test('$name is an invalid response', () async {
        server.handler = (_) => reply;
        final e = await _failure(provider.lookup(query, http));
        expect(e.kind, LyricsFetchKind.invalidResponse);
      });
    });

    final failing = <int, LyricsFetchKind>{
      302: LyricsFetchKind.server,
      400: LyricsFetchKind.server,
      401: LyricsFetchKind.server,
      403: LyricsFetchKind.server,
      451: LyricsFetchKind.server,
      500: LyricsFetchKind.server,
      502: LyricsFetchKind.server,
      429: LyricsFetchKind.rateLimited,
      503: LyricsFetchKind.rateLimited,
    };
    failing.forEach((status, kind) {
      test('status $status is $kind and never not-found', () async {
        server.handler = (_) => Reply(
          status,
          'plain text error',
          headers: const {'content-type': 'text/plain'},
        );
        expect((await _failure(provider.lookup(query, http))).kind, kind);
        expect(server.requests, hasLength(1));
      });
    });

    test('429 carries a clamped Retry-After', () async {
      Future<Duration?> waitFor(String? header) async {
        server.handler = (_) =>
            Reply(429, '', headers: {'retry-after': ?header});
        return (await _failure(provider.lookup(query, http))).retryAfter;
      }

      expect(await waitFor('7'), const Duration(seconds: 7));
      expect(await waitFor('99999'), const Duration(minutes: 15));
      expect(await waitFor('Wed, 21 Oct 2026 07:28:00 GMT'), isNull);
      expect(await waitFor(null), isNull);
    });
  });

  group('search', () {
    test('free text goes in q, ignoring the other fields', () async {
      server.handler = (_) => _ok([_record(id: 5), _record(id: 6)]);
      final found = await provider.search(
        const LyricsQuery(
          text: 'Đừng & hỏi/em?',
          title: 'ignored',
          artist: 'A',
        ),
        http,
      );
      expect(found.map((c) => c.remoteId), ['5', '6']);
      final request = server.requests.single;
      expect(request.uri.path, '/api/search');
      expect(request.uri.queryParameters, {'q': 'Đừng & hỏi/em?'});
    });

    test('structured search sends title and primary artist encoded', () async {
      server.handler = (_) => _ok(<Object?>[]);
      await provider.search(
        const LyricsQuery(title: 'Nơi/này & có Anh', artist: 'Sơn Tùng; B'),
        http,
      );
      final request = server.requests.single;
      expect(request.uri.path, '/api/search');
      expect(request.uri.queryParameters, {
        'track_name': 'Nơi/này & có Anh',
        'artist_name': 'Sơn Tùng',
      });
    });

    test('no title and no text sends nothing', () async {
      expect(
        await provider.search(const LyricsQuery(artist: 'A'), http),
        isEmpty,
      );
      expect(
        await provider.search(const LyricsQuery(text: '  '), http),
        isEmpty,
      );
      expect(server.requests, isEmpty);
    });

    test('skips invalid items and keeps at most 20', () async {
      server.handler = (_) => _ok([
        'junk',
        {'id': 'x'},
        _record(id: 2, track: 5),
        for (var i = 10; i < 40; i++) _record(id: i),
      ]);
      final found = await provider.search(query, http);
      expect(found, hasLength(20));
      expect(found.first.remoteId, '10');
    });

    test('an array with no usable record is invalid, not empty', () async {
      server.handler = (_) => _ok([
        'junk',
        5,
        {'id': 'x'},
      ]);
      expect(
        (await _failure(provider.search(query, http))).kind,
        LyricsFetchKind.invalidResponse,
      );
      server.handler = (_) => _ok(<Object?>[]);
      expect(await provider.search(query, http), isEmpty);
      server.handler = (_) => _ok(['junk', _record(id: 3)]);
      expect((await provider.search(query, http)).single.remoteId, '3');
    });

    test('a non-array answer is invalid', () async {
      server.handler = (_) => _ok(_record());
      expect(
        (await _failure(provider.search(query, http))).kind,
        LyricsFetchKind.invalidResponse,
      );
    });

    test('404 is an error for search, even with the not-found JSON', () async {
      server.handler = (_) =>
          const Reply(404, '{"name":"TrackNotFound"}', headers: _json);
      final e = await _failure(provider.search(query, http));
      expect(e.kind, LyricsFetchKind.invalidResponse);
    });
  });

  group('fetch', () {
    test('reads the body of a record by id', () async {
      server.handler = (_) => _ok(_record(id: 42, plain: 'words'));
      final body = (await provider.fetch('42', http))!;
      expect(body.plain, 'words');
      expect(server.requests.single.uri.path, '/api/get/42');
    });

    test('the id is one path segment', () async {
      await provider.fetch('4/../2', http);
      expect(server.requests.single.uri.path, '/api/get/4%2F..%2F2');
    });

    test('TrackNotFound gives null', () async {
      server.handler = (_) =>
          const Reply(404, '{"name":"TrackNotFound"}', headers: _json);
      expect(await provider.fetch('9', http), isNull);
    });
  });

  group('record sanitizing', () {
    test('strips controls and bidi overrides but keeps newlines', () {
      final c = parseLrclibRecord(
        _record(
          track: 'So\u0000ng\u202E\u2066',
          artist: 'A\u007F\u0007r',
          synced: '[00:01.00] a\u202Eb\r\n[00:02.00]\tc\u0001',
        ),
        providerId: 'lrclib',
      )!;
      expect(c.title, 'Song');
      expect(c.artist, 'Ar');
      expect(c.body!.syncedLrc, '[00:01.00] ab\n[00:02.00]\tc');
    });

    test('caps a display field at 512 characters', () {
      final c = parseLrclibRecord(_record(track: 'a' * 600), providerId: 'p')!;
      expect(c.title.runes, hasLength(512));
      final astral = parseLrclibRecord(
        _record(track: '\u{20000}' * 600),
        providerId: 'p',
      )!;
      expect(astral.title.runes, hasLength(512));
    });

    test('drops a body over 1 MiB and a blank body', () {
      final c = parseLrclibRecord(
        _record(synced: '[00:01.00] ${'a' * (1024 * 1024)}', plain: '  \n '),
        providerId: 'p',
      )!;
      expect(c.body!.syncedLrc, isNull);
      expect(c.body!.plain, isNull);
    });

    test('a field of the wrong type makes the record invalid', () {
      for (final record in [
        _record(duration: 'long'),
        _record(duration: -1),
        _record(duration: 1e16),
        _record(duration: 86401),
        _record(instrumental: 'yes'),
        _record(synced: 5),
        _record(album: 3),
        _record(track: '\u0000 '),
      ]) {
        expect(parseLrclibRecord(record, providerId: 'p'), isNull);
      }
    });
  });
}
