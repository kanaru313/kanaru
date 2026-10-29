import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../database/artist_names.dart';
import 'lrclib_record.dart';
import 'lyrics_fetch_exception.dart';
import 'lyrics_http.dart';
import 'lyrics_provider.dart';

/// Most records one search returns to the host.
const lrclibMaxSearchResults = 20;

/// The LRCLIB service (https://lrclib.net). Only the answers its API
/// documents are accepted: a 200 with a JSON body of the expected shape, and
/// a 404 whose JSON `name` is `TrackNotFound` (the one "not found"). Every
/// other answer, such as a captive portal's HTML 404, is an error and never a
/// reason to remember "no lyrics".
class LrclibProvider implements LyricsProvider {
  LrclibProvider({@visibleForTesting Uri? baseUri})
    : _base = baseUri ?? Uri.parse('https://lrclib.net');

  final Uri _base;

  @override
  String get id => 'lrclib';

  @override
  String get displayName => 'LRCLIB';

  @override
  List<String> get hosts => [_base.host];

  /// `GET /api/get` with the title, the primary artist, the album when known
  /// and the duration in whole seconds when it is 1..3600. Throws
  /// [ArgumentError] when the title or primary artist is missing (`null`
  /// means only that the service has no such record).
  @override
  Future<LyricsCandidate?> lookup(LyricsQuery query, LyricsHttp http) async {
    final title = query.title?.trim() ?? '';
    final artist = _primaryArtist(query.artist);
    if (title.isEmpty || artist.isEmpty) {
      throw ArgumentError('lookup needs a title and a primary artist');
    }
    final album = query.album?.trim() ?? '';
    final seconds = query.duration?.inMilliseconds;
    final rounded = seconds == null ? null : (seconds / 1000).round();
    final uri = _uri(
      const ['api', 'get'],
      {
        'track_name': title,
        'artist_name': artist,
        if (album.isNotEmpty) 'album_name': album,
        if (rounded != null && rounded >= 1 && rounded <= 3600)
          'duration': '$rounded',
      },
    );
    final found = await _getJson(http, uri);
    if (found.notFound) return null;
    return _record(found.json);
  }

  /// `GET /api/search` by free text (`q`), else by title and primary artist.
  /// No title and no text gives an empty list without a request.
  @override
  Future<List<LyricsCandidate>> search(
    LyricsQuery query,
    LyricsHttp http,
  ) async {
    final text = query.text?.trim() ?? '';
    final title = query.title?.trim() ?? '';
    if (text.isEmpty && title.isEmpty) return const [];
    final artist = _primaryArtist(query.artist);
    final uri = _uri(
      const ['api', 'search'],
      {
        if (text.isNotEmpty) 'q': text,
        if (text.isEmpty) 'track_name': title,
        if (text.isEmpty && artist.isNotEmpty) 'artist_name': artist,
      },
    );
    final json = (await _getJson(http, uri)).json;
    if (json is! List) {
      throw const LyricsFetchException(LyricsFetchKind.invalidResponse);
    }
    final records = [
      for (final item in json) ?parseLrclibRecord(item, providerId: id),
    ];
    // A non-empty array of nothing usable is a changed format, not "no
    // results".
    if (json.isNotEmpty && records.isEmpty) {
      throw const LyricsFetchException(LyricsFetchKind.invalidResponse);
    }
    return records.take(lrclibMaxSearchResults).toList(growable: false);
  }

  /// `GET /api/get/{id}`.
  @override
  Future<LyricsBody?> fetch(String remoteId, LyricsHttp http) async {
    if (remoteId.trim().isEmpty) return null;
    final found = await _getJson(http, _uri(['api', 'get', remoteId], {}));
    return found.notFound ? null : _record(found.json).body;
  }

  Uri _uri(List<String> path, Map<String, String> query) => _base.replace(
    pathSegments: path,
    queryParameters: query.isEmpty ? null : query,
  );

  String _primaryArtist(String? tag) {
    final names = splitArtists(tag);
    return names.isEmpty ? '' : names.first.trim();
  }

  LyricsCandidate _record(Object? json) =>
      parseLrclibRecord(json, providerId: id) ??
      (throw const LyricsFetchException(LyricsFetchKind.invalidResponse));

  /// The decoded JSON of a whitelisted answer; anything else throws.
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
        throw const LyricsFetchException(LyricsFetchKind.invalidResponse);
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
    if (!type.startsWith('application/json')) {
      throw const LyricsFetchException(LyricsFetchKind.invalidResponse);
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const LyricsFetchException(LyricsFetchKind.invalidResponse);
    }
  }
}
