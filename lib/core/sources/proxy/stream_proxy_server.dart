import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../remote_source_ref.dart';
import '../source_plugin_drops.dart';
import 'plugin_drop_watcher.dart';
import 'range_request.dart';
import 'resolved_streams.dart';
import 'stream_proxy_token.dart';
import 'stream_resolver.dart';
import 'upstream_reader.dart';

/// Install id, status and byte counts only: never the token, the upstream
/// URL or its query.
final _log = Logger('source_proxy');

/// The loopback server mpv plays remote tracks from.
///
/// Bound to `127.0.0.1` on the first [urlFor], on a port the OS picks, with
/// a random session token as the first path segment; both stay the same
/// until [close]. A request is served only when its `Host` is exactly
/// `127.0.0.1:<port>`, its method is `GET` (else 405) and its path is
/// `/<token>/<kind>/<installId>/<itemId>` of a begun playthrough (else 404,
/// empty body). The item is resolved lazily, on the first request.
class StreamProxyServer implements PluginDropTarget {
  StreamProxyServer({
    required Map<RemoteStreamKind, TrackStreamResolver> resolvers,
    required HttpClient client,
    required this._onDrop,
    DateTime Function()? clock,
    Random? random,
    int chunkBytes = upstreamChunkBytes,
    Duration resolveDeadline = streamResolveDeadline,
  }) : _resolvers = resolvers,
       _client = client,
       _token = StreamProxyToken(random ?? Random.secure()),
       _reader = UpstreamReader(client, chunkBytes: chunkBytes),
       _streams = {
         for (final MapEntry(:key, :value) in resolvers.entries)
           key: ResolvedStreams(
             value.resolve,
             clock: clock,
             resolveDeadline: resolveDeadline,
           ),
       };

  final Map<RemoteStreamKind, TrackStreamResolver> _resolvers;
  final HttpClient _client;
  final void Function(String installId) _onDrop;
  final StreamProxyToken _token;
  final UpstreamReader _reader;
  final Map<RemoteStreamKind, ResolvedStreams> _streams;
  final _dropped = <String>{};
  final _open = <String, Set<ProxyAnswer>>{};
  Future<HttpServer>? _server;
  bool _closed = false;

  /// The proxy URL of [ref]'s item. Begins a new playthrough of it (the
  /// player asks once per play); starts the server the first time.
  Future<String> urlFor(RemoteSourceRef ref) async {
    const kind = RemoteStreamKind.sourcePlugin;
    final server = await _bind();
    final key = '${ref.installId}/${ref.itemId}';
    final streams = _streams[kind];
    final owner = _resolvers[kind]?.ownerOf(key);
    if (streams != null && owner != null && !_dropped.contains(owner)) {
      streams.begin(key, owner);
    }
    return 'http://127.0.0.1:${server.port}/${_token.value}/${kind.segment}/'
        '${ref.installId}/${Uri.encodeComponent(ref.itemId)}';
  }

  /// Ends [installId]'s open responses, forgets its playthroughs, answers
  /// 404 for its items from now on, then tells the drop listeners.
  @override
  void dropPlugin(String installId) {
    if (_closed || !_dropped.add(installId)) return;
    for (final answer in _open.remove(installId)?.toList() ?? const []) {
      answer.abort();
    }
    for (final streams in _streams.values) {
      streams.dropOwner(installId);
    }
    _log.info('$installId dropped');
    _onDrop(installId);
  }

  /// Serves [installId]'s items again (from their next [urlFor]).
  @override
  void restorePlugin(String installId) => _dropped.remove(installId);

  /// Stops the server and every open response.
  Future<void> close() async {
    _closed = true;
    for (final answers in _open.values) {
      for (final answer in answers.toList()) {
        answer.abort();
      }
    }
    _open.clear();
    for (final streams in _streams.values) {
      streams.clear();
    }
    final server = _server;
    _server = null;
    _client.close(force: true);
    if (server != null) await (await server).close(force: true);
  }

  Future<HttpServer> _bind() {
    if (_closed) return Future.error(StateError('stream proxy closed'));
    return _server ??= _start().then(
      (server) => server,
      onError: (Object error, StackTrace trace) {
        _server = null;
        Error.throwWithStackTrace(error, trace);
      },
    );
  }

  Future<HttpServer> _start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      // Errors of a cut response (the client left, the body was ended
      // early) are not logged: they may name the requested path.
      unawaited(
        shelf_io
            .handleRequest(request, _handle, poweredByHeader: null)
            .catchError((Object _) {}),
      );
    }, onError: (Object _) {});
    _log.info('listening on port ${server.port}');
    return server;
  }

  Future<Response> _handle(Request request) async {
    try {
      return await _serve(request);
    } on Object {
      return Response(HttpStatus.badGateway);
    }
  }

  Future<Response> _serve(Request request) async {
    final server = await _server;
    if (server == null ||
        request.headers['host'] != '127.0.0.1:${server.port}') {
      return Response(HttpStatus.notFound);
    }
    if (request.method != 'GET') return Response(HttpStatus.methodNotAllowed);
    final segments = request.requestedUri.pathSegments;
    if (segments.length != 4 || !_token.matches(segments[0])) {
      return Response(HttpStatus.notFound);
    }
    final kind = RemoteStreamKind.fromSegment(segments[1]);
    final key = '${segments[2]}/${segments[3]}';
    final owner = kind == null ? null : _resolvers[kind]?.ownerOf(key);
    if (owner == null || _dropped.contains(owner)) {
      return Response(HttpStatus.notFound);
    }
    final playthrough = _streams[kind]?.lookup(key);
    if (playthrough == null) return Response(HttpStatus.notFound);
    final answer = await _reader.open(
      playthrough,
      RangeRequest.parse(request.headers['range']),
    );
    // Dropped while the first chunk was on its way.
    if (_dropped.contains(owner) || _closed) {
      answer.abort();
      return Response(HttpStatus.notFound);
    }
    final body = answer.body;
    if (body == null) {
      _log.info('$owner ${answer.status}');
      return Response(answer.status, headers: answer.headers);
    }
    final open = _open.putIfAbsent(owner, () => <ProxyAnswer>{})..add(answer);
    unawaited(
      answer.done.then((sent) {
        open.remove(answer);
        _log.fine('$owner ${answer.status} sent $sent bytes');
      }),
    );
    return Response(
      answer.status,
      headers: answer.headers,
      body: body,
      context: const {'shelf.io.buffer_output': false},
    );
  }
}

/// The app's stream proxy, created when the player first asks for a proxy
/// URL. Not disposed with the screen: port and token stay for the session.
final sourceStreamProxyProvider = Provider<StreamProxyServer>((ref) {
  final drops = ref.read(sourcePluginDropsProvider);
  final proxy = StreamProxyServer(
    resolvers: ref.read(trackStreamResolversProvider),
    client: newUpstreamClient(),
    onDrop: drops.add,
  );
  ref.onDispose(proxy.close);
  watchPluginDrops(ref, proxy);
  return proxy;
});
