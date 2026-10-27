import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One request the [LoopbackServer] received.
class RecordedRequest {
  RecordedRequest(this.method, this.uri, this.headers, this.body);

  final String method;
  final Uri uri;
  final HttpHeaders headers;
  final String body;

  /// Header [name] (any case), or `null`.
  String? header(String name) => headers.value(name);

  /// The decoded JSON body.
  Map<String, dynamic> get json => jsonDecode(body) as Map<String, dynamic>;

  /// Every `q` of a form body, in order.
  List<String> get formQ => Uri(query: body).queryParametersAll['q'] ?? [];
}

/// What the server answers: a [status], a [body], extra [headers], and an
/// optional [delay] before anything is written.
class Reply {
  const Reply(
    this.status,
    this.body, {
    this.headers = const {},
    this.delay = Duration.zero,
    this.bodyBytes,
    this.stallAfterPartial = false,
  });

  final int status;
  final String body;
  final Map<String, String> headers;
  final Duration delay;

  /// Sent instead of [body] when set.
  final List<int>? bodyBytes;

  /// Writes the headers and the first half of the body, then waits up to ten
  /// seconds for the client to hang up instead of finishing.
  final bool stallAfterPartial;
}

/// A real HTTP server on the loopback interface for client tests. Records
/// every request and answers with whatever [handler] returns.
class LoopbackServer {
  LoopbackServer._(this._server, this.handler) {
    _server.listen(_serve);
  }

  static Future<LoopbackServer> start(
    Reply Function(RecordedRequest request) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return LoopbackServer._(server, handler);
  }

  final HttpServer _server;
  Reply Function(RecordedRequest request) handler;
  final List<RecordedRequest> requests = [];
  final Completer<void> _stalledClientClosed = Completer<void>();

  /// Completes when the client closed a connection that [Reply.stallAfterPartial]
  /// left half answered.
  Future<void> get stalledClientClosed => _stalledClientClosed.future;

  Uri get baseUri => Uri.parse('http://127.0.0.1:${_server.port}');

  Future<void> _serve(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final recorded = RecordedRequest(
      request.method,
      request.uri,
      request.headers,
      body,
    );
    requests.add(recorded);
    final reply = handler(recorded);
    try {
      if (reply.delay > Duration.zero) await Future<void>.delayed(reply.delay);
      request.response.statusCode = reply.status;
      reply.headers.forEach(request.response.headers.set);
      final bytes = reply.bodyBytes ?? utf8.encode(reply.body);
      if (reply.stallAfterPartial) {
        // Raw socket: the declared length is never reached, and the socket
        // tells when the client hung up.
        request.response.contentLength = bytes.length;
        final socket = await request.response.detachSocket();
        socket.add(bytes.sublist(0, bytes.length ~/ 2));
        await socket.flush();
        socket.listen(
          (_) {},
          onDone: _stalledClientClosed.complete,
          onError: (_) => _stalledClientClosed.complete(),
          cancelOnError: true,
        );
        await _stalledClientClosed.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {},
        );
        socket.destroy();
        return;
      }
      request.response.add(bytes);
      await request.response.close();
    } on Object {
      // The client gave up (timeout test); nothing to answer.
    }
  }

  Future<void> close() => _server.close(force: true);
}
