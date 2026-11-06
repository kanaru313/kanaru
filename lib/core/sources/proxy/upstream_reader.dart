import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:logging/logging.dart';

import '../../lyrics/online/lyrics_http_pinned_connect.dart';
import 'proxy_body.dart';
import 'range_request.dart';
import 'resolved_streams.dart';
import 'stream_resolver.dart';
import 'upstream_headers.dart';

export 'proxy_body.dart' show ProxyAnswer;

final _log = Logger('source_proxy');

/// The largest upstream range asked for at once: some services refuse an
/// open-ended range, so every upstream request names its last byte.
const upstreamChunkBytes = 8 * 1024 * 1024;

/// The most redirects one upstream request follows (googlevideo sends a
/// 302 to another of its hosts now and then).
const maxUpstreamRedirects = 3;

/// How long an upstream answer's headers may take.
const upstreamHeaderTimeout = Duration(seconds: 15);

/// The client the proxy fetches upstream audio with: the bytes as sent
/// (no decompression), bounded connect and idle times, and connections only
/// to public addresses. Redirects are refused per request.
HttpClient newUpstreamClient() => HttpClient()
  ..autoUncompress = false
  ..connectionTimeout = const Duration(seconds: 10)
  ..idleTimeout = const Duration(seconds: 15)
  ..connectionFactory = lyricsPublicOnlyConnectionFactory();

/// The upstream answer gave nothing usable. [reason] names why, never the
/// URL (it carries signed query parameters).
class _Refused implements Exception {
  const _Refused(this.reason);

  final String reason;
}

/// Why an upstream request failed, for the log: a kind, an HTTP status or
/// an errno, never the URL or a message that may hold it.
String upstreamFailureReason(Object error) => switch (error) {
  _Refused(:final reason) => reason,
  PlaythroughEnded() => 'item dead or playthrough ended',
  ResolveFailure(:final reason) => 'resolve failed: $reason',
  SocketException(:final osError) =>
    'network error (errno ${osError?.errorCode ?? '?'})',
  HandshakeException() => 'TLS handshake failed',
  TimeoutException() => 'timeout',
  HttpException() => 'HTTP protocol error',
  _ => error.runtimeType.toString(),
};

typedef _Upstream = ({HttpClientResponse response, ResolvedStream stream});

/// Serves one request of a playthrough from upstream, in bounded chunks.
///
/// Every upstream request carries the stream's headers,
/// `accept-encoding: identity` and `range: bytes=p-q` with at most
/// [chunkBytes] bytes, and follows no redirect. The stream's consent is
/// asked before each one. A 403 goes to the playthrough, which gives a
/// fresh stream once and then marks the item dead.
class UpstreamReader {
  UpstreamReader(this._client, {this.chunkBytes = upstreamChunkBytes});

  final HttpClient _client;
  final int chunkBytes;

  /// The answer to a request for [range] of [playthrough]'s item: `200` or
  /// `206` with a streaming body, `416` for a range it cannot serve, or
  /// `502` when upstream fails before the headers.
  Future<ProxyAnswer> open(Playthrough playthrough, RangeRequest range) async {
    if (range is UnsatisfiableRange) {
      return ProxyAnswer.status(HttpStatus.requestedRangeNotSatisfiable);
    }
    try {
      var from = 0;
      int? last;
      if (range is ByteRange) {
        from = range.start;
        last = range.end;
      } else if (range is SuffixRange) {
        // The total is needed first: one probe of a single byte.
        final probe = await _fetch(playthrough, 0, 0);
        discardUpstream(probe.response);
        final total = _total(probe.response);
        final span = total == null ? null : range.within(total);
        if (span == null) return _unsatisfied(probe.response.headers);
        from = span.start;
        last = span.end;
      }
      final firstEnd = from + chunkBytes - 1;
      final first = await _fetch(
        playthrough,
        from,
        math.min(firstEnd, last ?? firstEnd),
      );
      return _answer(playthrough, first, range, from: from, last: last);
    } on Object catch (error) {
      // Refused, dead, ended, a failed resolve or a network error. Only the
      // reason is logged: the error itself may name the upstream URL.
      _log.info('upstream failed: ${upstreamFailureReason(error)}');
      return ProxyAnswer.status(HttpStatus.badGateway);
    }
  }

  ProxyAnswer _answer(
    Playthrough playthrough,
    _Upstream first,
    RangeRequest range, {
    required int from,
    required int? last,
  }) {
    final response = first.response;
    final status = response.statusCode;
    if (status == HttpStatus.requestedRangeNotSatisfiable) {
      discardUpstream(response);
      return _unsatisfied(response.headers);
    }
    final total = _total(response);
    final ranged = status == HttpStatus.partialContent;
    final goodStart = ranged
        ? parseContentRange(response.headers.value('content-range'))?.start ==
              from
        : from == 0;
    final span = total == null
        ? null
        : (last == null ? ByteRange(from) : ByteRange(from, last)).within(
            total,
          );
    if (total == null || !goodStart || (span == null && range.partial)) {
      discardUpstream(response);
      return total == null || !goodStart
          ? ProxyAnswer.status(HttpStatus.badGateway)
          : _unsatisfied(response.headers);
    }
    if (span == null) {
      // No range asked and an empty body.
      discardUpstream(response);
      return ProxyAnswer.status(HttpStatus.ok, {
        'accept-ranges': 'bytes',
        'content-length': '0',
      });
    }
    final type =
        safeMediaType(first.stream.mimeType) ??
        safeMediaType(response.headers.value('content-type'));
    final pump = ProxyBodyPump(
      first: response,
      start: span.start,
      end: span.end,
      total: total,
      // A 200 already holds every byte from the first one on.
      chunked: ranged,
      chunkBytes: chunkBytes,
      fetch: (start, end) async =>
          (await _fetch(playthrough, start, end)).response,
    );
    return streamingProxyAnswer(
      range.partial ? HttpStatus.partialContent : HttpStatus.ok,
      {
        'accept-ranges': 'bytes',
        'content-length': '${span.end - span.start + 1}',
        if (range.partial)
          'content-range': 'bytes ${span.start}-${span.end}/$total',
        'content-type': ?type,
      },
      pump,
    );
  }

  static ProxyAnswer _unsatisfied(HttpHeaders upstream) {
    final value = upstream.value('content-range');
    final total =
        unsatisfiedRangeTotal(value) ?? parseContentRange(value)?.total;
    return ProxyAnswer.status(HttpStatus.requestedRangeNotSatisfiable, {
      if (total != null) 'content-range': 'bytes */$total',
    });
  }

  /// The size of the whole body: from a `206`'s `Content-Range`, or a
  /// `200`'s `Content-Length`. Null when the answer tells neither, is
  /// another status, or is encoded.
  static int? _total(HttpClientResponse response) {
    final encoding = response.headers.value('content-encoding');
    if (encoding != null && encoding.toLowerCase() != 'identity') return null;
    if (response.statusCode == HttpStatus.partialContent) {
      return parseContentRange(response.headers.value('content-range'))?.total;
    }
    if (response.statusCode == HttpStatus.ok && response.contentLength >= 0) {
      return response.contentLength;
    }
    return null;
  }

  /// One upstream request for `start..end` with a usable status (200, 206
  /// or 416). A 403 is retried with what the playthrough gives; a redirect
  /// or any other status is refused.
  Future<_Upstream> _fetch(Playthrough playthrough, int start, int end) async {
    var used = playthrough.current();
    while (true) {
      final stream = await used;
      if (!stream.allowed()) throw const _Refused('consent withdrawn');
      final response = await _get(stream, start, end);
      final status = response.statusCode;
      if (status == HttpStatus.forbidden) {
        _log.info('upstream 403, resolving again');
        discardUpstream(response);
        used = playthrough.onForbidden(used);
        continue;
      }
      if (status != HttpStatus.ok &&
          status != HttpStatus.partialContent &&
          status != HttpStatus.requestedRangeNotSatisfiable) {
        discardUpstream(response);
        throw _Refused('upstream status $status');
      }
      return (response: response, stream: stream);
    }
  }

  /// Fetches `bytes=start-end` of [stream], following at most
  /// [maxUpstreamRedirects] redirects whose target passes the stream's
  /// [ResolvedStream.redirectAllowed]; any other redirect is refused.
  Future<HttpClientResponse> _get(
    ResolvedStream stream,
    int start,
    int end,
  ) async {
    var url = stream.url;
    for (var hop = 0; ; hop++) {
      final response = await _getOnce(stream, url, start, end);
      if (!response.isRedirect) return response;
      discardUpstream(response);
      final location = response.headers.value(HttpHeaders.locationHeader);
      final target = location == null ? null : url.resolve(location);
      final allows = stream.redirectAllowed;
      if (hop >= maxUpstreamRedirects) {
        throw const _Refused('too many upstream redirects');
      }
      if (target == null || allows == null || !allows(target)) {
        throw _Refused('upstream redirect refused (${response.statusCode})');
      }
      url = target;
    }
  }

  Future<HttpClientResponse> _getOnce(
    ResolvedStream stream,
    Uri url,
    int start,
    int end,
  ) async {
    final request = await _client.getUrl(url);
    request
      ..followRedirects = false
      ..maxRedirects = 0;
    stream.headers.forEach(request.headers.set);
    request.headers
      ..set(HttpHeaders.acceptEncodingHeader, 'identity')
      ..set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
    return request.close().timeout(
      upstreamHeaderTimeout,
      onTimeout: () {
        request.abort();
        throw const _Refused('upstream headers timed out');
      },
    );
  }
}
