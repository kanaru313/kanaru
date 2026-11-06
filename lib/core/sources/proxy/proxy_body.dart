import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'upstream_headers.dart';

/// Opens the upstream bytes `start..end` (both included). Throws when no
/// usable answer comes (consent withdrawn, item dead, network).
typedef ChunkFetch = Future<HttpClientResponse> Function(int start, int end);

/// How long an upstream body may send nothing while the client reads.
const upstreamStallTimeout = Duration(seconds: 15);

/// What the proxy answers one request with. A [body] streams the bytes as
/// they come from upstream; [abort] ends it at once.
class ProxyAnswer {
  ProxyAnswer.status(this.status, [this.headers = const {}])
    : body = null,
      _pump = null;

  ProxyAnswer._streaming(this.status, this.headers, ProxyBodyPump pump)
    : body = pump.stream,
      _pump = pump;

  final int status;
  final Map<String, String> headers;
  final Stream<List<int>>? body;
  final ProxyBodyPump? _pump;

  /// The bytes sent once the body ended (the end, an abort, a failure or
  /// the client leaving). Zero at once without a body.
  Future<int> get done => _pump?.done ?? Future.value(0);

  /// Ends the body now; the client sees it cut short.
  void abort() => _pump?.close();
}

/// Builds the streaming answer of [pump].
ProxyAnswer streamingProxyAnswer(
  int status,
  Map<String, String> headers,
  ProxyBodyPump pump,
) => ProxyAnswer._streaming(status, headers, pump);

/// Streams the bytes `start..end` to the client: first the body of the
/// upstream answer already open, then, when [chunked], one bounded upstream
/// request per chunk of [chunkBytes]. The client's pauses pause the
/// upstream; the client leaving cancels it. A failure after the headers
/// ends the body.
class ProxyBodyPump {
  ProxyBodyPump({
    required HttpClientResponse this._first,
    required int start,
    required this._end,
    required this._chunked,
    required this._chunkBytes,
    required this._fetch,
  }) : _pos = start {
    _out
      ..onListen = _listen
      ..onPause = (() => _sub?.pause())
      ..onResume = (() => _sub?.resume())
      ..onCancel = close;
  }

  final _out = StreamController<List<int>>();
  final _done = Completer<int>();
  HttpClientResponse? _first;
  int _pos;
  final int _end;
  final bool _chunked;
  final int _chunkBytes;
  final ChunkFetch _fetch;
  StreamSubscription<List<int>>? _sub;
  bool _closed = false;
  int _sent = 0;

  Stream<List<int>> get stream => _out.stream;
  Future<int> get done => _done.future;

  /// Ends the body and cancels the upstream answer being read.
  void close() {
    if (_closed) return;
    _closed = true;
    final first = _first;
    _first = null;
    if (first != null) discardUpstream(first);
    final sub = _sub;
    _sub = null;
    unawaited(sub?.cancel());
    unawaited(_out.close());
    _done.complete(_sent);
  }

  void _listen() {
    final first = _first;
    _first = null;
    if (first != null) _pipe(first);
  }

  void _pipe(HttpClientResponse response) {
    if (_closed) {
      discardUpstream(response);
      return;
    }
    var got = 0;
    _sub = response
        .timeout(upstreamStallTimeout)
        .listen(
          (data) {
            if (_closed) return;
            final room = _end - _pos + 1;
            final bytes = data.length > room ? data.sublist(0, room) : data;
            _out.add(bytes);
            _pos += bytes.length;
            _sent += bytes.length;
            got += bytes.length;
            // More than was asked for: the rest is not read.
            if (data.length > room) close();
          },
          onError: (Object _) => close(),
          onDone: () {
            _sub = null;
            if (_closed) return;
            if (_pos > _end || !_chunked || got == 0) {
              // Done, or an answer that cannot be continued.
              close();
            } else {
              unawaited(_next());
            }
          },
          cancelOnError: true,
        );
    if (_out.isPaused) _sub!.pause();
  }

  Future<void> _next() async {
    final HttpClientResponse response;
    try {
      response = await _fetch(_pos, math.min(_pos + _chunkBytes - 1, _end));
    } on Object {
      close();
      return;
    }
    final range = parseContentRange(response.headers.value('content-range'));
    if (_closed ||
        response.statusCode != HttpStatus.partialContent ||
        range == null ||
        range.start != _pos) {
      discardUpstream(response);
      close();
      return;
    }
    _pipe(response);
  }
}

/// Drops an upstream answer without reading it; its connection is closed.
void discardUpstream(HttpClientResponse response) {
  unawaited(response.listen(null, onError: (Object _) {}).cancel());
}
