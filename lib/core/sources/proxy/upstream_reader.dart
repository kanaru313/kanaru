import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import '../../lyrics/online/lyrics_http_pinned_connect.dart';
import 'proxy_body.dart';
import 'range_request.dart';
import 'resolved_streams.dart';
import 'stream_resolver.dart';
import 'upstream_headers.dart';

export 'proxy_body.dart' show ProxyAnswer;

/// The largest upstream range asked for at once: some services refuse an
/// open-ended range, so every upstream request names its last byte.
const upstreamChunkBytes = 8 * 1024 * 1024;

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

/// The upstream answer gave nothing usable.
class _Refused implements Exception {
  const _Refused();
}

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
    } on Object {
      // Refused, dead, ended, a failed resolve or a network error: never
      // logged here, the error may name the upstream URL.
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
      if (!stream.allowed()) throw const _Refused();
      final response = await _get(stream, start, end);
      final status = response.statusCode;
      if (status == HttpStatus.forbidden) {
        discardUpstream(response);
        used = playthrough.onForbidden(used);
        continue;
      }
      if (status != HttpStatus.ok &&
          status != HttpStatus.partialContent &&
          status != HttpStatus.requestedRangeNotSatisfiable) {
        discardUpstream(response);
        throw const _Refused();
      }
      return (response: response, stream: stream);
    }
  }

  Future<HttpClientResponse> _get(
    ResolvedStream stream,
    int start,
    int end,
  ) async {
    final request = await _client.getUrl(stream.url);
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
        throw const _Refused();
      },
    );
  }
}
