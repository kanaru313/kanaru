import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'proxy_body.dart';
import 'stream_resolver.dart';

/// The most redirects one upstream request follows (googlevideo sends a
/// 302 to another of its hosts now and then).
const maxUpstreamRedirects = 3;

/// How long an upstream answer's headers may take.
const upstreamHeaderTimeout = Duration(seconds: 15);

/// The upstream answer gave nothing usable. [reason] names why, never the
/// URL (it carries signed query parameters).
class UpstreamRefused implements Exception {
  const UpstreamRefused(this.reason);

  /// A fixed phrase or an HTTP status, safe to log.
  final String reason;

  @override
  String toString() => 'UpstreamRefused($reason)';
}

/// Why [readUpstreamBody] gave no body.
enum UpstreamBodyFailureKind { tooLong, tooSlow }

/// A body that was longer than allowed or did not come in time. Carries no
/// URL.
class UpstreamBodyFailure implements Exception {
  const UpstreamBodyFailure(this.kind);

  final UpstreamBodyFailureKind kind;

  /// For the log: a fixed phrase.
  String get reason => switch (kind) {
    UpstreamBodyFailureKind.tooLong => 'upstream body too long',
    UpstreamBodyFailureKind.tooSlow => 'upstream body too slow',
  };

  @override
  String toString() => 'UpstreamBodyFailure($reason)';
}

/// One checked upstream GET of [url] for [stream].
///
/// The request carries the stream's headers, `accept-encoding: identity`
/// and, when [range] is given, `range: bytes=start-end` (closed). A redirect
/// is followed by hand at most [maxUpstreamRedirects] times, and only to a
/// target the stream's [ResolvedStream.redirectAllowed] accepts (a relative
/// `Location` is resolved against the URL that redirected); any other
/// redirect, a missing `Location` included, throws [UpstreamRefused] and its
/// body is discarded. The answer's headers must come within [headerTimeout].
///
/// The result holds the response, whatever its status (the caller judges it,
/// a redirect aside), and the URL it finally came from: the last redirect
/// target, else [url]. Relative URIs of a playlist resolve against it.
/// Asking the stream's consent is the caller's job.
Future<({HttpClientResponse response, Uri url})> fetchUpstream(
  HttpClient client,
  ResolvedStream stream,
  Uri url, {
  ({int start, int end})? range,
  Duration headerTimeout = upstreamHeaderTimeout,
}) async {
  var current = url;
  for (var hop = 0; ; hop++) {
    final response = await _getOnce(
      client,
      stream,
      current,
      range,
      headerTimeout,
    );
    if (!response.isRedirect) return (response: response, url: current);
    discardUpstream(response);
    final location = response.headers.value(HttpHeaders.locationHeader);
    final target = location == null ? null : current.resolve(location);
    final allows = stream.redirectAllowed;
    if (hop >= maxUpstreamRedirects) {
      throw const UpstreamRefused('too many upstream redirects');
    }
    if (target == null || allows == null || !allows(target)) {
      throw UpstreamRefused(
        'upstream redirect refused (${response.statusCode})',
      );
    }
    current = target;
  }
}

Future<HttpClientResponse> _getOnce(
  HttpClient client,
  ResolvedStream stream,
  Uri url,
  ({int start, int end})? range,
  Duration headerTimeout,
) async {
  final request = await client.getUrl(url);
  request
    ..followRedirects = false
    ..maxRedirects = 0;
  stream.headers.forEach(request.headers.set);
  request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
  if (range != null) {
    request.headers.set(
      HttpHeaders.rangeHeader,
      'bytes=${range.start}-${range.end}',
    );
  }
  return request.close().timeout(
    headerTimeout,
    onTimeout: () {
      request.abort();
      throw const UpstreamRefused('upstream headers timed out');
    },
  );
}

/// The whole body of [response], at most [maxBytes] long and complete within
/// [timeout] of the call (so a body that stalls, or trickles, past it ends).
///
/// Throws [UpstreamBodyFailure] when the body is longer (a declared length
/// above [maxBytes] is refused before any byte is read) or too slow; either
/// way the rest is not read and the connection is dropped. A network error
/// on the body is rethrown.
Future<List<int>> readUpstreamBody(
  HttpClientResponse response, {
  required int maxBytes,
  required Duration timeout,
}) {
  if (response.contentLength > maxBytes) {
    discardUpstream(response);
    return Future.error(
      const UpstreamBodyFailure(UpstreamBodyFailureKind.tooLong),
    );
  }
  final result = Completer<List<int>>();
  final body = BytesBuilder(copy: false);
  late final StreamSubscription<List<int>> subscription;
  late final Timer timer;

  void fail(Object error, [StackTrace? stack]) {
    timer.cancel();
    unawaited(subscription.cancel());
    if (!result.isCompleted) result.completeError(error, stack);
  }

  timer = Timer(
    timeout,
    () => fail(const UpstreamBodyFailure(UpstreamBodyFailureKind.tooSlow)),
  );
  subscription = response.listen(
    (data) {
      if (body.length + data.length > maxBytes) {
        fail(const UpstreamBodyFailure(UpstreamBodyFailureKind.tooLong));
        return;
      }
      body.add(data);
    },
    onError: fail,
    onDone: () {
      timer.cancel();
      if (!result.isCompleted) result.complete(body.takeBytes());
    },
    cancelOnError: true,
  );
  return result.future;
}
