import 'dart:io';

import 'package:logging/logging.dart';

import '../proxy_body.dart';
import '../range_request.dart';
import '../resolved_streams.dart';
import '../upstream_fetch.dart';
import '../upstream_reader.dart' show upstreamFailureReason;
import 'hls_proxy_names.dart';
import 'hls_request_failure.dart';
import 'hls_resource_answer.dart';
import 'hls_snapshot.dart';
import 'hls_snapshot_memory.dart';

export 'hls_resource_answer.dart' show hlsKeyBodyTimeout, hlsKeyBytes;

/// Install id, kind, status and byte counts only: never a URL, query, header
/// or token.
final _log = Logger('source_proxy');

/// The longest segment served; a longer body is cut here, and one that says
/// it is longer is refused.
const hlsMaxSegmentBytes = 32 * 1024 * 1024;

/// The longest init section served.
const hlsMaxInitBytes = 4 * 1024 * 1024;

/// How many times one request may be answered 403 before it gives up; the
/// playthrough itself ends the item at the second.
const _maxForbidden = 3;

/// Serves one sub-resource (segment, init section or key) of an HLS item.
///
/// The request names a snapshot `rev`. It is served when that is the rev of
/// the snapshot in the playthrough's current resolve, or a remembered rev of
/// the same item whose layout equals the current snapshot's (then resource
/// i of the current snapshot is served); otherwise `404` (unknown) or `502`
/// (another layout). Every upstream request goes through [fetchUpstream]
/// after the stream's consent was asked, with a closed `range` only for a
/// byte-range segment or init section. A `403` goes to the playthrough, which
/// gives a fresh stream once and then marks the item dead; the request is
/// retried on the snapshot that comes back, if its layout is the same.
///
/// The client's `Range` is answered over the whole resource: an upstream
/// body is read from its start, so a range starting later drops the bytes
/// before it (and needs the size).
class HlsResourceReader {
  HlsResourceReader(
    this._client,
    this._memory, {
    this.segmentLimit = hlsMaxSegmentBytes,
    this.initLimit = hlsMaxInitBytes,
    this.stallTimeout = upstreamStallTimeout,
    this.keyTimeout = hlsKeyBodyTimeout,
  });

  final HttpClient _client;
  final HlsSnapshotMemory _memory;
  final int segmentLimit;
  final int initLimit;
  final Duration stallTimeout;
  final Duration keyTimeout;

  /// The answer to a request for [range] of [resource] of [playthrough]'s
  /// item: `200` or `206` with a streaming body, `404` for a resource the
  /// item does not have, `416` for a range it cannot serve, or `502` when
  /// upstream fails or the item is dead.
  Future<ProxyAnswer> open(
    Playthrough playthrough,
    HlsResource resource,
    RangeRequest range,
  ) async {
    if (range is UnsatisfiableRange) {
      return ProxyAnswer.status(HttpStatus.requestedRangeNotSatisfiable);
    }
    try {
      return await _serve(playthrough, resource, range);
    } on Object catch (error) {
      final reason = switch (error) {
        HlsRequestFailure(:final reason) => reason,
        _ => upstreamFailureReason(error),
      };
      _log.info(
        '${playthrough.owner} hls ${resource.kind.name} failed: '
        '$reason',
      );
      return ProxyAnswer.status(HttpStatus.badGateway);
    }
  }

  Future<ProxyAnswer> _serve(
    Playthrough playthrough,
    HlsResource resource,
    RangeRequest range,
  ) async {
    var used = playthrough.current();
    // The layout the request's rev stands for, kept across a retry so it is
    // compared with the snapshot a fresh resolve brings.
    HlsLayout? asked;
    for (var forbidden = 0; forbidden < _maxForbidden; forbidden++) {
      final stream = await used;
      final snapshot = stream.hls;
      if (snapshot == null) return ProxyAnswer.status(HttpStatus.notFound);
      asked ??= snapshot.rev == resource.rev
          ? snapshot.layout
          : _memory.layoutOf(playthrough.key, resource.rev);
      if (asked == null) return ProxyAnswer.status(HttpStatus.notFound);
      if (asked != snapshot.layout) {
        throw const HlsRequestFailure(HlsRequestFailureKind.layoutChanged);
      }
      final target = _target(resource, snapshot);
      if (target == null) return ProxyAnswer.status(HttpStatus.notFound);
      final byteRange = target.byteRange;
      if (byteRange != null && byteRange.length > target.limit) {
        throw const UpstreamRefused('hls resource too long');
      }
      if (!stream.allowed()) throw const UpstreamRefused('consent withdrawn');
      final response = (await fetchUpstream(
        _client,
        stream,
        target.uri,
        range: byteRange == null
            ? null
            : (start: byteRange.offset, end: byteRange.end - 1),
      )).response;
      if (response.statusCode == HttpStatus.forbidden) {
        _log.info('${playthrough.owner} hls upstream 403, resolving again');
        discardUpstream(response);
        used = playthrough.onForbidden(used);
        continue;
      }
      return answerHlsResource(
        resource,
        target,
        response,
        range,
        stallTimeout: stallTimeout,
        keyTimeout: keyTimeout,
      );
    }
    // The last retry may leave a dead playthrough's error unawaited.
    used.ignore();
    throw const UpstreamRefused('upstream 403');
  }

  /// What [resource] is in [snapshot]; null when the snapshot has no such
  /// segment, init section or key.
  HlsTarget? _target(HlsResource resource, HlsSnapshot snapshot) {
    final i = resource.index;
    switch (resource.kind) {
      case HlsResourceKind.segment:
        final segments = snapshot.playlist.segments;
        if (i >= segments.length) return null;
        final segment = segments[i];
        return (
          uri: segment.uri,
          byteRange: segment.byteRange,
          limit: segmentLimit,
        );
      case HlsResourceKind.init:
        if (i >= snapshot.inits.length) return null;
        final init = snapshot.inits[i];
        return (uri: init.uri, byteRange: init.byteRange, limit: initLimit);
      case HlsResourceKind.key:
        if (i >= snapshot.keys.length) return null;
        return (uri: snapshot.keys[i], byteRange: null, limit: hlsKeyBytes);
    }
  }
}
