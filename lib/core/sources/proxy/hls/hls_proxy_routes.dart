import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import '../../source_models.dart' show RemoteStreamFormat;
import '../proxy_body.dart';
import '../range_request.dart';
import '../resolved_streams.dart';
import '../stream_resolver.dart';
import '../upstream_reader.dart' show upstreamFailureReason;
import 'hls_playlist_loader.dart';
import 'hls_proxy_names.dart';
import 'hls_proxy_playlist.dart';
import 'hls_resource_reader.dart';

/// Install id, status and `hls <kind>` only: never a URL, query or token.
final _log = Logger('source_proxy');

/// How long [HlsProxyRoutes.formatOf] waits for the resolve of an item.
/// Shorter than the 30 s the player's hook waits, so its own null comes first.
const formatOfTimeout = Duration(seconds: 25);

/// The `content-type` of the playlist the proxy writes for an HLS item.
const _playlistType = 'application/vnd.apple.mpegurl';

/// The HLS side of the stream proxy: loads the playlist inside each resolve,
/// answers the proxy-written playlist at an item's entry URL, serves its
/// segments, init sections and keys, and tells the format of a resolve.
/// The caller has already checked the request (Host, token, owner, kept
/// playthrough).
class HlsProxyRoutes {
  HlsProxyRoutes(HttpClient client, {this.formatDeadline = formatOfTimeout})
    : _loader = HlsPlaylistLoader(client) {
    _reader = HlsResourceReader(client, _loader.memory);
  }

  final HlsPlaylistLoader _loader;
  late final HlsResourceReader _reader;

  /// How long [formatOf] waits for a resolve.
  final Duration formatDeadline;

  /// [inner] with an HLS stream's playlist loaded and checked.
  StreamResolve wrap(StreamResolve inner) => hlsAwareResolve(inner, _loader);

  /// The answer to a request for sub-resource [resource] of [playthrough]'s
  /// item.
  Future<ProxyAnswer> open(
    Playthrough playthrough,
    HlsResource resource,
    RangeRequest range,
  ) => _reader.open(playthrough, resource, range);

  /// The answer at an item's entry URL when its current resolve is HLS, else
  /// null (a progressive item, left to the caller). Waits for the resolve; a
  /// failed one is `502` and logged. [entryUrl] is the URL asked, [gone] says
  /// whether the owner was dropped or the proxy closed meanwhile.
  Future<Response?> entry(
    Playthrough playthrough,
    String entryUrl, {
    required bool Function() gone,
  }) async {
    final ResolvedStream stream;
    try {
      stream = await playthrough.current();
    } on Object catch (error) {
      final reason = upstreamFailureReason(error);
      // A [ResolveFailure] reason already starts with `resolve failed`.
      _log.info(
        '${playthrough.owner} '
        '${error is ResolveFailure ? reason : 'resolve failed: $reason'}',
      );
      return Response(HttpStatus.badGateway);
    }
    if (stream.format != RemoteStreamFormat.hls) return null;
    return _playlist(playthrough.owner, stream, entryUrl, gone: gone());
  }

  /// The proxy-written playlist of [stream]'s snapshot, whatever `Range` the
  /// client sent. Its URIs are `<entryUrl>/<name>`. [gone]: the owner was
  /// dropped or the proxy closed meanwhile (404). `502` when there is no
  /// snapshot or the consent was withdrawn.
  Response _playlist(
    String owner,
    ResolvedStream stream,
    String entryUrl, {
    required bool gone,
  }) {
    if (gone) return Response(HttpStatus.notFound);
    final snapshot = stream.hls;
    if (snapshot == null || !stream.allowed()) {
      _log.info(
        '$owner hls playlist 502: '
        '${snapshot == null ? 'no snapshot' : 'consent withdrawn'}',
      );
      return Response(HttpStatus.badGateway);
    }
    final bytes = utf8.encode(
      writeHlsProxyPlaylist(snapshot, (name) => '$entryUrl/$name'),
    );
    _log.fine('$owner 200 hls playlist ${bytes.length} bytes');
    return Response.ok(
      bytes,
      headers: {
        'content-type': _playlistType,
        'content-length': '${bytes.length}',
      },
    );
  }

  /// The format of [playthrough]'s current resolve (started if need be), or
  /// null when it fails, after [formatDeadline], or when [gone] says the owner
  /// was dropped or the proxy closed meanwhile. Never throws.
  Future<RemoteStreamFormat?> formatOf(
    Playthrough playthrough,
    bool Function() gone,
  ) async {
    try {
      final stream = await playthrough.current().timeout(formatDeadline);
      return gone() ? null : stream.format;
    } on Object {
      return null;
    }
  }
}
