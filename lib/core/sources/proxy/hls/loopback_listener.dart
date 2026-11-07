import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

final _log = Logger('source_proxy');

/// An HTTP server on `127.0.0.1` and a port the OS picks, bound on the first
/// [bind] and kept until [close]; every request goes to [handler].
class LoopbackListener {
  LoopbackListener(this.handler);

  final Handler handler;
  Future<HttpServer>? _server;

  /// The server once [bind] was called and until [close]; null before.
  Future<HttpServer>? get started => _server;

  /// The server, bound now if it is not yet. A failed bind is not kept, so
  /// the next call tries again.
  Future<HttpServer> bind() => _server ??= _start().then(
    (server) => server,
    onError: (Object error, StackTrace trace) {
      _server = null;
      Error.throwWithStackTrace(error, trace);
    },
  );

  /// Stops the server and the requests being served.
  Future<void> close() async {
    final server = _server;
    _server = null;
    if (server != null) await (await server).close(force: true);
  }

  Future<HttpServer> _start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(
      (request) {
        // shelf answers a handler error with a 500 itself; what is left is a
        // cut response (the client left, the body ended early), common when
        // mpv seeks. Logged as its type only: the message may name the
        // requested path, token included.
        unawaited(
          shelf_io
              .handleRequest(request, handler, poweredByHeader: null)
              .catchError((Object error) {
                _log.fine('response cut: ${error.runtimeType}');
              }),
        );
      },
      onError: (Object error) {
        _log.warning('server error: ${error.runtimeType}');
      },
    );
    _log.info('listening on port ${server.port}');
    return server;
  }
}
