import 'dart:io';

import '../../hls/hls_limits.dart';
import '../../hls/hls_playlist_parser.dart';
import '../../source_models.dart' show RemoteStreamFormat;
import '../proxy_body.dart';
import '../resolved_streams.dart';
import '../stream_resolver.dart';
import '../upstream_fetch.dart';
import '../upstream_reader.dart' show upstreamFailureReason;
import 'hls_resolve_failure.dart';
import 'hls_snapshot.dart';
import 'hls_snapshot_memory.dart';

/// How long a playlist body may take, counted from its headers.
const hlsPlaylistBodyTimeout = Duration(seconds: 15);

/// Loads and checks the HLS playlist of a [ResolvedStream].
///
/// The playlist (and, for a master, the one media playlist its variant
/// choice names) is fetched with the stream's headers and consent, redirects
/// checked, then parsed with the URL it finally came from as base. Every
/// segment, init section and key URL must pass the stream's
/// [ResolvedStream.redirectAllowed]; one that does not, a `data:` URI
/// included, refuses the whole playlist (`blockedHost`).
class HlsPlaylistLoader {
  HlsPlaylistLoader(
    this._client, {
    this.bodyTimeout = hlsPlaylistBodyTimeout,
    HlsSnapshotMemory? memory,
  }) : memory = memory ?? HlsSnapshotMemory();

  final HttpClient _client;
  final Duration bodyTimeout;

  /// The revs handed out and the layouts remembered.
  final HlsSnapshotMemory memory;

  /// The snapshot of [stream], which is an HLS stream of item [key]. Throws
  /// [ResolveForbidden] on a 403, [HlsResolveFailure] for a playlist that is
  /// refused or too big or slow, and [ResolveFailure] for anything else.
  Future<HlsSnapshot> load(
    String key,
    ResolvedStream stream, {
    required bool Function() abandoned,
  }) async {
    var fetched = await _fetch(stream, stream.url, abandoned);
    final first = fetched.playlist;
    if (first is HlsMasterPlaylist) {
      final variant = _refusing(() => chooseHlsVariant(first));
      _checkDerived(stream, [variant]);
      fetched = await _fetch(stream, variant, abandoned);
    }
    final media = fetched.playlist;
    if (media is! HlsMediaPlaylist) {
      // A master behind a master.
      throw HlsResolveFailure(HlsRefusalKind.invalid);
    }
    final derived = <Uri>{};
    for (final segment in media.segments) {
      derived.add(segment.uri);
      final key = segment.key;
      if (key != null) derived.add(key.uri);
      final init = segment.init;
      if (init != null) {
        derived.add(init.uri);
        // The key in force at the MAP line may be none of the segments' keys.
        final initKey = init.key;
        if (initKey != null) derived.add(initKey.uri);
      }
    }
    _checkDerived(stream, derived);
    return HlsSnapshot.build(media, (layout) => memory.remember(key, layout));
  }

  Future<({HlsPlaylist playlist, Uri url})> _fetch(
    ResolvedStream stream,
    Uri url,
    bool Function() abandoned,
  ) async {
    if (abandoned()) throw const ResolveFailure('abandoned');
    if (!stream.allowed()) throw const ResolveFailure('consent withdrawn');
    final List<int> body;
    final Uri finalUrl;
    try {
      final fetched = await fetchUpstream(_client, stream, url);
      final response = fetched.response;
      finalUrl = fetched.url;
      final status = response.statusCode;
      if (status == HttpStatus.forbidden) {
        discardUpstream(response);
        throw const ResolveForbidden();
      }
      if (status != HttpStatus.ok) {
        discardUpstream(response);
        throw ResolveFailure('upstream status $status');
      }
      body = await readUpstreamBody(
        response,
        maxBytes: hlsMaxPlaylistBytes,
        timeout: bodyTimeout,
      );
    } on UpstreamBodyFailure {
      throw HlsResolveFailure(HlsRefusalKind.tooLarge);
    } on ResolveFailure {
      rethrow;
    } on Object catch (error) {
      throw ResolveFailure(upstreamFailureReason(error));
    }
    final playlist = _refusing(() => parseHlsPlaylist(body, finalUrl));
    return (playlist: playlist, url: finalUrl);
  }

  void _checkDerived(ResolvedStream stream, Iterable<Uri> uris) {
    final allows = stream.redirectAllowed;
    for (final uri in uris) {
      final http = uri.scheme == 'http' || uri.scheme == 'https';
      if (!http || allows == null || !allows(uri)) {
        throw HlsResolveFailure(HlsRefusalKind.blockedHost);
      }
    }
  }

  T _refusing<T>(T Function() body) {
    try {
      return body();
    } on HlsRefusal catch (refusal) {
      throw HlsResolveFailure(refusal.kind);
    }
  }
}

/// Wraps [inner] so an HLS stream comes back with its playlist loaded and
/// checked (`ResolvedStream.hls`); a progressive stream passes through
/// untouched.
StreamResolve hlsAwareResolve(StreamResolve inner, HlsPlaylistLoader loader) =>
    (key, {required fresh, required abandoned}) async {
      final stream = await inner(key, fresh: fresh, abandoned: abandoned);
      if (stream.format != RemoteStreamFormat.hls) return stream;
      return stream.withHls(
        await loader.load(key, stream, abandoned: abandoned),
      );
    };
