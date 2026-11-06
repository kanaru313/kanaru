import 'dart:convert';

import 'package:kanaru/core/database/artist_names.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_artist_match.dart'
    show isUnknownArtist;
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';

/// Host the provider registers with unless a test names another.
const httpTestHost = 'lyrics.test.net';

/// A minimal provider for the HTTP-layer tests: it issues one GET per call
/// through the [LyricsHttp] it is given, so host pinning, the public-only
/// guard, consent and retries are exercised the way a real source meets them.
///
/// `lookup` is `GET /api/get`, `search` is `GET /api/search`, `fetch` is
/// `GET /api/get/{id}`. A 200 with a JSON body is an answer, a 404 whose JSON
/// `name` is `TrackNotFound` is "not found", 429 and 503 are `rateLimited`
/// (with `Retry-After`), anything else is an error.
class HttpTestLyricsProvider implements LyricsProvider {
  HttpTestLyricsProvider({List<String> hosts = const [httpTestHost]})
    : hosts = List.unmodifiable(hosts);

  @override
  final List<String> hosts;

  @override
  String get id => 'test-http';

  @override
  String get displayName => 'Test HTTP';

  Uri _uri(List<String> path, Map<String, String> query) => Uri(
    scheme: 'https',
    host: hosts.first,
    pathSegments: path,
    queryParameters: query.isEmpty ? null : query,
  );

  @override
  Future<LyricsCandidate?> lookup(LyricsQuery query, LyricsHttp http) async {
    final title = query.title?.trim() ?? '';
    final names = splitArtists(query.artist);
    final artist = names.isEmpty ? '' : names.first.trim();
    if (title.isEmpty || artist.isEmpty) {
      throw ArgumentError('lookup needs a title and a primary artist');
    }
    final seconds = query.duration?.inSeconds;
    final found = await _getJson(
      http,
      _uri(
        const ['api', 'get'],
        {
          'track_name': title,
          'artist_name': artist,
          if (seconds != null && seconds >= 1 && seconds <= 3600)
            'duration': '$seconds',
        },
      ),
    );
    return found.notFound ? null : _record(found.json);
  }

  @override
  Future<List<LyricsCandidate>> search(
    LyricsQuery query,
    LyricsHttp http,
  ) async {
    final text = query.text?.trim() ?? '';
    final title = query.title?.trim() ?? '';
    if (text.isEmpty && title.isEmpty) return const [];
    final names = [
      for (final name in splitArtists(query.artist))
        if (name.trim().isNotEmpty && !isUnknownArtist(name)) name.trim(),
    ];
    final json = (await _getJson(
      http,
      _uri(
        const ['api', 'search'],
        {
          if (text.isNotEmpty) 'q': text else 'track_name': title,
          if (text.isEmpty && names.length == 1) 'artist_name': names.single,
        },
      ),
    )).json;
    if (json is! List) throw _invalid();
    return [for (final item in json) _record(item)];
  }

  @override
  Future<LyricsBody?> fetch(String remoteId, LyricsHttp http) async {
    if (remoteId.trim().isEmpty) return null;
    final found = await _getJson(http, _uri(['api', 'get', remoteId], {}));
    return found.notFound ? null : _record(found.json).body;
  }

  LyricsFetchException _invalid() =>
      const LyricsFetchException(LyricsFetchKind.invalidResponse);

  LyricsCandidate _record(Object? json) {
    if (json is! Map) throw _invalid();
    final id = json['id'];
    final track = json['trackName'];
    final artist = json['artistName'];
    if (id is! int || track is! String || artist is! String) throw _invalid();
    final album = json['albumName'];
    final seconds = json['duration'];
    final synced = json['syncedLyrics'];
    final plain = json['plainLyrics'];
    return LyricsCandidate(
      providerId: this.id,
      remoteId: '$id',
      title: track,
      artist: artist,
      album: album is String && album.isNotEmpty ? album : null,
      duration: seconds is num
          ? Duration(milliseconds: (seconds * 1000).round())
          : null,
      body: LyricsBody(
        syncedLrc: synced is String && synced.trim().isNotEmpty ? synced : null,
        plain: plain is String && plain.trim().isNotEmpty ? plain : null,
        instrumental: json['instrumental'] == true,
      ),
    );
  }

  Future<({Object? json, bool notFound})> _getJson(
    LyricsHttp http,
    Uri uri,
  ) async {
    final response = await http.get(uri);
    switch (response.status) {
      case 200:
        return (json: _decode(response), notFound: false);
      case 404:
        final json = _decode(response);
        if (json is Map && json['name'] == 'TrackNotFound') {
          return (json: null, notFound: true);
        }
        throw _invalid();
      case 429 || 503:
        throw LyricsFetchException(
          LyricsFetchKind.rateLimited,
          retryAfter: parseRetryAfter(response.headers['retry-after']),
        );
      default:
        throw const LyricsFetchException(LyricsFetchKind.server);
    }
  }

  Object? _decode(LyricsHttpResponse response) {
    final type = response.headers['content-type']?.toLowerCase() ?? '';
    if (!type.startsWith('application/json')) throw _invalid();
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw _invalid();
    }
  }
}
