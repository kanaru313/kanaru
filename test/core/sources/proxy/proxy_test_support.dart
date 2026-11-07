import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kanaru/core/sources/proxy/stream_resolver.dart';

/// Install id used by the proxy tests.
const testInstallId = 'plugin-abc123def456';

/// [length] bytes whose value tells their offset (`offset % 251`).
List<int> testBytes(int length) => [for (var i = 0; i < length; i++) i % 251];

/// One request the fake upstream saw.
typedef UpstreamRequest = ({String path, String? range, HttpHeaders headers});

/// A loopback HTTP server standing in for the audio host. Serves [bytes]
/// with `Range` like a CDN; a test can refuse paths with 403, redirect,
/// leave out the length headers, or send slowly.
class FakeUpstream {
  FakeUpstream._(this._server, this.bytes) {
    _server.listen(_serve);
  }

  static Future<FakeUpstream> start(List<int> bytes) async => FakeUpstream._(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    bytes,
  );

  final HttpServer _server;
  final List<int> bytes;
  final requests = <UpstreamRequest>[];

  /// Paths answered 403.
  final forbidden = <String>{};

  /// Paths answered 403 once they served the given number of requests.
  final forbiddenAfter = <String, int>{};

  /// Paths answered 302 to another place: [redirectTo] when it names one
  /// for the path, else `/elsewhere`.
  final redirected = <String>{};
  final redirectTo = <String, String>{};

  /// Paths that serve another body than [bytes] (another file).
  final bodies = <String, List<int>>{};

  /// Paths that answer another `content-type` than [contentType].
  final contentTypes = <String, String>{};

  /// Paths answered with this status and an empty body (404, 500, ...).
  final statuses = <String, int>{};

  /// Answers 206 without `Content-Range` and without `Content-Length`.
  bool omitLengths = false;

  /// Answers 200 with the whole body, whatever the `Range`.
  bool ignoreRange = false;

  /// Sent as `content-type`.
  String contentType = 'audio/webm';

  /// Each answer is written in pieces of [piece] bytes with [pause] between
  /// them.
  int piece = 64 * 1024;
  Duration pause = Duration.zero;

  /// Answers whose client went away before the whole body was written.
  int cutShort = 0;

  /// Completes each time an answer is cut short.
  final _cuts = StreamController<void>.broadcast();
  Stream<void> get cuts => _cuts.stream;

  Uri url(String path) => Uri.parse('http://127.0.0.1:${_server.port}$path');

  /// The `Range` headers seen, in order.
  List<String?> get ranges => [for (final r in requests) r.range];

  Future<void> close() async {
    await _server.close(force: true);
    await _cuts.close();
  }

  Future<void> _serve(HttpRequest request) async {
    final path = request.uri.path;
    final bytes = bodies[path] ?? this.bytes;
    final range = request.headers.value('range');
    requests.add((path: path, range: range, headers: request.headers));
    final response = request.response;
    final served = requests.where((r) => r.path == path).length - 1;
    final limit = forbiddenAfter[path];
    if (forbidden.contains(path) || (limit != null && served >= limit)) {
      response.statusCode = HttpStatus.forbidden;
      await response.close();
      return;
    }
    final status = statuses[path];
    if (status != null) {
      response.statusCode = status;
      await response.close();
      return;
    }
    if (redirected.contains(path)) {
      response
        ..statusCode = HttpStatus.found
        ..headers.set(
          'location',
          url(redirectTo[path] ?? '/elsewhere').toString(),
        );
      await response.close();
      return;
    }
    var start = 0;
    var end = bytes.length - 1;
    final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range ?? '');
    final ranged = match != null && !ignoreRange;
    if (ranged) {
      start = int.parse(match.group(1)!);
      if (match.group(2)!.isNotEmpty) {
        end = int.parse(match.group(2)!).clamp(0, bytes.length - 1);
      }
      if (start >= bytes.length) {
        response
          ..statusCode = HttpStatus.requestedRangeNotSatisfiable
          ..headers.set('content-range', 'bytes */${bytes.length}');
        await response.close();
        return;
      }
    }
    response
      ..statusCode = ranged ? HttpStatus.partialContent : HttpStatus.ok
      // The body is written on the detached socket, so the connection is
      // not kept for another request.
      ..persistentConnection = false
      ..headers.set('content-type', contentTypes[path] ?? contentType);
    if (omitLengths) {
      response.headers.chunkedTransferEncoding = false;
    } else {
      response.contentLength = end - start + 1;
      if (ranged) {
        response.headers.set(
          'content-range',
          'bytes $start-$end/${bytes.length}',
        );
      }
    }
    // Written by hand on the socket, which tells at once when the client
    // closes it (a server response does not).
    final socket = await response.detachSocket();
    var finished = false;
    var closed = false;
    socket.listen(
      null,
      onError: (Object _) => closed = true,
      onDone: () {
        closed = true;
        if (finished) return;
        cutShort++;
        // The client may close after the test ended and closed the fake.
        if (!_cuts.isClosed) _cuts.add(null);
      },
    );
    try {
      for (var at = start; at <= end && !closed; at += piece) {
        final to = (at + piece).clamp(0, end + 1);
        socket.add(bytes.sublist(at, to));
        await socket.flush();
        if (to > end) {
          // The whole body is out: a client closing from now on is not a
          // cut, and there is no pause after the last piece.
          finished = !closed;
          break;
        }
        if (pause > Duration.zero) await Future<void>.delayed(pause);
      }
      await socket.close();
    } on Object {
      socket.destroy();
    }
  }
}

/// A resolver that hands out URLs of a [FakeUpstream] and counts its calls
/// (each one stands for a `stream.js` run). The n-th call (from 1) resolves
/// to path `/s<n>`.
class CountingResolver implements TrackStreamResolver {
  CountingResolver(this.upstream);

  final FakeUpstream upstream;

  /// The `fresh` flag of each call, in order.
  final calls = <bool>[];

  /// The key of each call, in order.
  final keys = <String>[];

  /// The plugin's consent, asked by the streams handed out.
  bool allowed = true;

  /// The type the plugin reports.
  String? mimeType = 'audio/webm';

  /// When the URLs handed out expire.
  DateTime? expiresAt;

  /// Makes the next calls fail.
  bool failing = false;

  /// Handed to the streams as their redirect rule; null follows none.
  bool Function(Uri url)? redirectAllowed;

  /// Completes the calls only when set; null answers at once.
  Completer<void>? gate;

  @override
  String? ownerOf(String key) {
    final slash = key.indexOf('/');
    return slash <= 0 ? null : key.substring(0, slash);
  }

  @override
  Future<ResolvedStream> resolve(
    String key, {
    required bool fresh,
    required bool Function() abandoned,
  }) async {
    calls.add(fresh);
    keys.add(key);
    final n = calls.length;
    await gate?.future;
    if (failing) throw const ResolveFailure('unavailable');
    return ResolvedStream(
      url: upstream.url('/s$n'),
      headers: const {'x-plugin': 'yes', 'user-agent': 'PluginAgent'},
      mimeType: mimeType,
      expiresAt: expiresAt,
      allowed: () => allowed,
      redirectAllowed: redirectAllowed,
    );
  }
}

/// A raw HTTP/1.1 answer read from a socket until the server closed it.
class RawAnswer {
  RawAnswer(this.status, this.headers, this.body);

  final int status;
  final Map<String, String> headers;
  final List<int> body;
}

/// Sends one `GET` over a fresh socket as mpv does (`Connection: close`)
/// and reads the answer until the socket closes. [host] replaces the
/// `Host` header.
Future<RawAnswer> rawRequest(
  Uri url, {
  String method = 'GET',
  String? host,
  String? range,
}) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, url.port);
  socket.write(
    '$method ${url.path} HTTP/1.1\r\n'
    'Host: ${host ?? '127.0.0.1:${url.port}'}\r\n'
    'User-Agent: libmpv\r\n'
    'Accept: */*\r\n'
    '${range == null ? '' : 'Range: $range\r\n'}'
    'Connection: close\r\n'
    'Icy-MetaData: 1\r\n\r\n',
  );
  final bytes = <int>[];
  await socket
      .listen(bytes.addAll, onError: (Object _) {})
      .asFuture<void>()
      .catchError((Object _) {});
  socket.destroy();
  return parseRawAnswer(bytes);
}

/// An answer being read over a raw socket, as mpv reads one.
class OpenRawRequest {
  OpenRawRequest._(this._socket) {
    _socket.listen(
      received.addAll,
      onError: (Object _) => _finish(),
      onDone: _finish,
    );
  }

  static Future<OpenRawRequest> send(Uri url, {String? range}) async {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, url.port);
    socket.write(
      'GET ${url.path} HTTP/1.1\r\n'
      'Host: 127.0.0.1:${url.port}\r\n'
      '${range == null ? '' : 'Range: $range\r\n'}'
      'Connection: close\r\n\r\n',
    );
    return OpenRawRequest._(socket);
  }

  final Socket _socket;
  final received = <int>[];
  final _closed = Completer<void>();

  /// Completes once the server closed the connection.
  Future<void> get closed => _closed.future;

  void _finish() {
    if (!_closed.isCompleted) _closed.complete();
  }

  void destroy() {
    _socket.destroy();
    _finish();
  }
}

/// Splits a raw answer into status, headers (lower-case names) and body.
RawAnswer parseRawAnswer(List<int> bytes) {
  var split = -1;
  for (var i = 0; i + 3 < bytes.length; i++) {
    if (bytes[i] == 13 &&
        bytes[i + 1] == 10 &&
        bytes[i + 2] == 13 &&
        bytes[i + 3] == 10) {
      split = i;
      break;
    }
  }
  if (split < 0) return RawAnswer(0, const {}, bytes);
  final lines = latin1.decode(bytes.sublist(0, split)).split('\r\n');
  final status = int.parse(lines.first.split(' ')[1]);
  final headers = <String, String>{
    for (final line in lines.skip(1))
      line.substring(0, line.indexOf(':')).toLowerCase(): line
          .substring(line.indexOf(':') + 1)
          .trim(),
  };
  return RawAnswer(status, headers, bytes.sublist(split + 4));
}

/// Polls until [condition] holds, failing after five seconds.
Future<void> until(bool Function() condition) async {
  final clock = Stopwatch()..start();
  while (!condition()) {
    if (clock.elapsed > const Duration(seconds: 5)) {
      throw TimeoutException('condition never held');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
