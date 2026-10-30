import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart' show addTearDown;

import '../core/lyrics/online/lookup_test_harness.dart'
    show RewritingHttpClient;
import '../core/lyrics_translation/loopback_server.dart';

/// Records of a small LRCLIB, in the JSON shape of the real API.
const lrclibRecords = <Map<String, Object?>>[
  // A song with synced and plain lyrics, a cover with another artist, and a
  // plain-only live version.
  {
    'id': 101,
    'trackName': 'Synced Song',
    'artistName': 'Synced Artist',
    'albumName': 'First Album',
    'duration': 200.4,
    'instrumental': false,
    'plainLyrics': 'first line\nsecond line',
    'syncedLyrics': '[00:01.00] first line\n[00:05.50] second line',
  },
  {
    'id': 102,
    'trackName': 'Synced Song',
    'artistName': 'Synced Artist',
    'albumName': 'Live Album',
    'duration': 231,
    'instrumental': false,
    'plainLyrics': 'first line live',
    'syncedLyrics': null,
  },
  {
    'id': 103,
    'trackName': 'Synced Song',
    'artistName': 'Cover Band',
    'albumName': 'Synced Artist Tribute',
    'duration': 200,
    'instrumental': false,
    'plainLyrics': 'cover words',
    'syncedLyrics': '[00:02.00] cover words',
  },
  // A song that has plain lyrics only.
  {
    'id': 201,
    'trackName': 'Plain Song',
    'artistName': 'Plain Artist',
    'albumName': 'Second Album',
    'duration': 180,
    'instrumental': false,
    'plainLyrics': 'only plain words',
    'syncedLyrics': null,
  },
  // An instrumental song.
  {
    'id': 301,
    'trackName': 'Instrumental Song',
    'artistName': 'Instrumental Artist',
    'albumName': 'Third Album',
    'duration': 240,
    'instrumental': true,
    'plainLyrics': null,
    'syncedLyrics': null,
  },
  // A record whose duration is 0, and one the app must refuse whole (over a
  // day), both for the same song.
  {
    'id': 401,
    'trackName': 'Zero Song',
    'artistName': 'Zero Artist',
    'albumName': 'Fourth Album',
    'duration': 0,
    'instrumental': false,
    'plainLyrics': 'zero words',
    'syncedLyrics': null,
  },
  {
    'id': 402,
    'trackName': 'Zero Song',
    'artistName': 'Zero Artist',
    'albumName': 'Broken Album',
    'duration': 100000,
    'instrumental': false,
    'plainLyrics': 'broken words',
    'syncedLyrics': '[00:01.00] broken words',
  },
  // A title with a control character and stray spaces.
  {
    'id': 501,
    'trackName': '  Messy\u0001 Song  ',
    'artistName': 'Messy Artist',
    'albumName': 'Fifth Album',
    'duration': 160,
    'instrumental': false,
    'plainLyrics': 'messy words',
    'syncedLyrics': null,
  },
];

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Reply _json(int status, Object? body) =>
    Reply(status, jsonEncode(body), headers: _jsonHeaders);

final _notFound = _json(404, {
  'code': 404,
  'name': 'TrackNotFound',
  'message': 'Failed to find specified track',
});

bool _same(Object? a, String b) => '$a'.toLowerCase() == b.toLowerCase();

/// Answers like LRCLIB for [lrclibRecords]:
/// * `/api/get?track_name&artist_name[&duration]`: the first record with
///   that title and artist, else a `TrackNotFound` 404;
/// * `/api/get/<id>`: that record, else the same 404;
/// * `/api/search?q=...`: records where every word of the text is in the
///   title, artist or album; `/api/search?track_name=...[&artist_name=...]`:
///   records whose title contains the title (and artist the artist).
Reply lrclibReply(RecordedRequest request) {
  final path = request.uri.pathSegments;
  final query = request.uri.queryParameters;
  if (path.length == 3 && path[0] == 'api' && path[1] == 'get') {
    final id = int.tryParse(path[2]);
    final found = lrclibRecords.where((r) => r['id'] == id);
    return found.isEmpty ? _notFound : _json(200, found.first);
  }
  if (path.length == 2 && path[0] == 'api' && path[1] == 'get') {
    final found = lrclibRecords.where(
      (r) =>
          _same(r['trackName'], query['track_name'] ?? '') &&
          _same(r['artistName'], query['artist_name'] ?? ''),
    );
    return found.isEmpty ? _notFound : _json(200, found.first);
  }
  if (path.length == 2 && path[0] == 'api' && path[1] == 'search') {
    final words = (query['q'] ?? '').toLowerCase().split(' ')
      ..removeWhere((w) => w.isEmpty);
    final title = query['track_name']?.toLowerCase();
    final artist = query['artist_name']?.toLowerCase();
    final found = [
      for (final r in lrclibRecords)
        if (words.isNotEmpty
            ? words.every(
                (w) => '${r['trackName']} ${r['artistName']} ${r['albumName']}'
                    .toLowerCase()
                    .contains(w),
              )
            : '${r['trackName']}'.toLowerCase().contains(title ?? '\u0000') &&
                  (artist == null ||
                      '${r['artistName']}'.toLowerCase().contains(artist)))
          r,
    ];
    return _json(200, found);
  }
  return _json(404, {'code': 404, 'name': 'NotFound'});
}

/// Sends every request of the providers to [server] whatever its host, so the
/// providers keep their real `https://lrclib.net` addresses and the strict
/// host rules of the app apply. A path under `/down` fails like a dropped
/// connection, to test a script that hides a network error.
class LrclibRoutingClient extends RewritingHttpClient {
  /// Closed when the test ends.
  LrclibRoutingClient(LoopbackServer server) : super(server.baseUri) {
    addTearDown(() => close(force: true));
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    if (url.path.startsWith('/down')) {
      opened++;
      return Future.error(const SocketException('connection dropped'));
    }
    return super.openUrl(method, url);
  }
}
