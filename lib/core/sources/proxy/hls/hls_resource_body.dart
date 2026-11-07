import 'dart:async';

import '../proxy_body.dart';

/// Streams one HLS sub-resource to the client: drops the first [skip] bytes
/// of the upstream body, sends at most [limit] bytes after them, then ends.
/// The client's pauses pause the upstream; the client leaving, [close], a
/// failure or an upstream that sends nothing for [stallTimeout] ends the body
/// and drops the upstream read.
///
/// The segment, init and key bodies are never continued with a second
/// upstream request: the upstream answer already holds every byte asked for.
class HlsBodyPump {
  HlsBodyPump(
    this._source, {
    required this._skip,
    required this._limit,
    required this._stallTimeout,
  }) {
    _out
      ..onListen = _listen
      ..onPause = (() => _sub?.pause())
      ..onResume = (() => _sub?.resume())
      ..onCancel = close;
  }

  final Stream<List<int>> _source;
  final Duration _stallTimeout;
  final _out = StreamController<List<int>>();
  final _done = Completer<int>();
  StreamSubscription<List<int>>? _sub;
  int _skip;
  final int _limit;
  int _sent = 0;
  bool _closed = false;
  bool _listened = false;

  Stream<List<int>> get stream => _out.stream;

  /// The bytes sent once the body ended.
  Future<int> get done => _done.future;

  /// Ends the body now and cancels the upstream read. A body nobody listened
  /// to yet (the plugin was dropped while the segment was on its way) still
  /// drops the upstream: the source is listened to and cancelled at once, so
  /// an upstream response closes its connection.
  void close() {
    if (_closed) return;
    _closed = true;
    final sub = _sub;
    _sub = null;
    if (sub != null) {
      unawaited(sub.cancel());
    } else if (!_listened) {
      unawaited(_source.listen(null, onError: (Object _) {}).cancel());
    }
    unawaited(_out.close());
    _done.complete(_sent);
  }

  void _listen() {
    if (_closed) return;
    _listened = true;
    _sub = _source
        .timeout(_stallTimeout)
        .listen(
          _onData,
          onError: (Object _) => close(),
          onDone: close,
          cancelOnError: true,
        );
    if (_out.isPaused) _sub!.pause();
  }

  void _onData(List<int> data) {
    if (_closed) return;
    var bytes = data;
    if (_skip > 0) {
      if (bytes.length <= _skip) {
        _skip -= bytes.length;
        return;
      }
      bytes = bytes.sublist(_skip);
      _skip = 0;
    }
    final room = _limit - _sent;
    if (bytes.length > room) bytes = bytes.sublist(0, room);
    _out.add(bytes);
    _sent += bytes.length;
    if (_sent >= _limit) close();
  }
}

/// The answer to an HLS sub-resource request: status and headers, and a
/// [HlsBodyPump] body that [abort] ends.
class HlsAnswer extends ProxyAnswer {
  HlsAnswer(super.status, super.headers, this._pump) : super.status();

  final HlsBodyPump _pump;

  @override
  Stream<List<int>> get body => _pump.stream;

  @override
  Future<int> get done => _pump.done;

  @override
  void abort() => _pump.close();
}
