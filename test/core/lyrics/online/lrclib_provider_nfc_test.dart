import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/text_keys.dart';
import 'package:kanaru/core/lyrics/online/lrclib_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_match.dart';
import 'package:kanaru/core/lyrics/online/lyrics_match_keys.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';

import '../../lyrics_translation/loopback_server.dart';

// "Nói" and "Yêu" with o/e plus a combining mark, as macOS taggers write.
const _nfdTitle = 'Chau Khai Phong Nghe Nói Anh Yêu Em';
const _nfcTitle = 'Chau Khai Phong Nghe Nói Anh Yêu Em';
// Hangul as conjoining jamo (NFD) and as syllables (NFC).
const _nfdHangul = '한';
const _nfcHangul = '한';

void main() {
  late HttpClient client;
  late LoopbackServer server;
  late LrclibProvider provider;
  late LyricsHttp http;

  setUp(() async {
    client = HttpClient();
    server = await LoopbackServer.start((request) {
      final record = {
        'id': 1,
        'trackName': 'x',
        'artistName': 'y',
        'duration': 200,
        'instrumental': false,
        'plainLyrics': 'hi',
      };
      final isSearch = request.uri.path == '/api/search';
      return Reply(
        200,
        jsonEncode(isSearch ? [record] : record),
        headers: {'content-type': 'application/json'},
      );
    });
    provider = LrclibProvider(baseUri: server.baseUri);
    http = LyricsHttp.forTesting(
      client: client,
      hosts: provider.hosts,
      maxRetries: 0,
    );
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  test('nfcText composes Vietnamese and Hangul, leaves NFC alone', () {
    expect(nfcText(_nfdTitle), _nfcTitle);
    expect(nfcText(_nfcTitle), _nfcTitle);
    expect(nfcText(_nfdHangul), _nfcHangul);
    expect(nfcText('Plain Text'), 'Plain Text');
  });

  test('lookup sends title and artist in NFC, without the album', () async {
    await provider.lookup(
      const LyricsQuery(
        title: _nfdTitle,
        artist: 'Châu; Yêu',
        album: 'Nói $_nfdHangul',
        duration: Duration(seconds: 200),
      ),
      http,
    );
    expect(server.requests.single.uri.queryParameters, {
      'track_name': _nfcTitle,
      'artist_name': 'Châu',
      'duration': '200',
    });
  });

  test('lookup sends a decomposed artist in NFC', () async {
    await provider.lookup(
      const LyricsQuery(
        title: 'S',
        artist: 'Châu',
        duration: Duration(seconds: 200),
      ),
      http,
    );
    expect(server.requests.single.uri.queryParameters['artist_name'], 'Châu');
  });

  test('search sends free text in NFC', () async {
    await provider.search(const LyricsQuery(text: _nfdTitle), http);
    expect(server.requests.single.uri.queryParameters, {'q': _nfcTitle});
  });

  test('search by title and artist sends both in NFC', () async {
    await provider.search(
      const LyricsQuery(title: _nfdTitle, artist: 'Châu'),
      http,
    );
    expect(server.requests.single.uri.queryParameters, {
      'track_name': _nfcTitle,
      'artist_name': 'Châu',
    });
  });

  test('a decomposed local tag matches a composed remote record', () {
    final candidate = LyricsCandidate(
      providerId: 'lrclib',
      remoteId: '1',
      title: _nfcTitle,
      artist: 'Châu Khai Phong',
      duration: const Duration(seconds: 200),
      body: const LyricsBody(plain: 'a'),
    );
    for (final tag in [_nfdTitle, _nfcTitle]) {
      final query = LyricsQuery(
        title: tag,
        artist: 'Châu Khai Phong',
        duration: const Duration(seconds: 200),
      );
      expect(matchCandidate(query, candidate).goodMatch, isTrue, reason: tag);
    }
  });

  test('NFD and NFC tags share one cache key', () {
    String key(String title, String artist, String album) =>
        onlineLyricsCacheKey(
          LyricsQuery(
            title: title,
            artist: artist,
            album: album,
            duration: const Duration(seconds: 200),
          ),
        );
    expect(
      key(_nfdTitle, 'Châu', 'Nói $_nfdHangul'),
      key(_nfcTitle, 'Châu', 'Nói $_nfcHangul'),
    );
  });
}
