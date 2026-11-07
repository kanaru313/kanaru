import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import '../remote_source_ref.dart';
import '../source_models.dart' show RemoteStreamFormat;
import '../source_plugin_drops.dart';
import 'hls/hls_proxy_names.dart';
import 'hls/hls_proxy_routes.dart';
import 'hls/loopback_listener.dart';
import 'hls/proxy_items.dart';
import 'hls/proxy_open_answers.dart';
import 'plugin_drop_watcher.dart';
import 'range_request.dart';
import 'resolved_streams.dart';
import 'stream_proxy_token.dart';
import 'stream_resolver.dart';
import 'upstream_reader.dart';

export 'hls/hls_proxy_routes.dart' show formatOfTimeout;

/// Install id, status and byte counts only: never a token, URL or query.
final _log = Logger('source_proxy');

/// The loopback server mpv plays remote tracks from.
///
/// Bound to `127.0.0.1` on the first [urlFor], on a port the OS picks, with
/// a random session token as the first path segment; both stay the same
/// until [close]. A request is served only when its `Host` is exactly
/// `127.0.0.1:<port>`, its method is `GET` (else 405) and its path is
/// `/<token>/<kind>/<installId>/<itemId>` of a begun playthrough that is
/// still kept (else 404, empty body; see [maxPlaythroughKeys]). The item is
/// resolved lazily, on the first request.
///
/// A progressive item answers its bytes at that path. An HLS item answers
/// there the playlist the proxy wrote, and its segments, init sections and
/// keys at `<path>/hls/<rev>/<name>` (see `hls_proxy_names.dart`), under the
/// same checks and the same playthrough.
class StreamProxyServer implements PluginDropTarget {
  StreamProxyServer({
    required Map<RemoteStreamKind, TrackStreamResolver> resolvers,
    required HttpClient client,
    required this._onDrop,
    DateTime Function()? clock,
    Random? random,
    int chunkBytes = upstreamChunkBytes,
    Duration resolveDeadline = streamResolveDeadline,
    Duration formatDeadline = formatOfTimeout,
  }) : _client = client,
       _token = StreamProxyToken(random ?? Random.secure()),
       _reader = UpstreamReader(client, chunkBytes: chunkBytes),
       _hls = HlsProxyRoutes(client, formatDeadline: formatDeadline) {
    _listener = LoopbackListener(_handle);
    _items = ProxyItems(resolvers, {
      for (final MapEntry(:key, :value) in resolvers.entries)
        key: ResolvedStreams(
          _hls.wrap(value.resolve),
          clock: clock,
          resolveDeadline: resolveDeadline,
        ),
    });
  }

  final HttpClient _client;
  final void Function(String installId) _onDrop;
  final StreamProxyToken _token;
  final UpstreamReader _reader;
  final HlsProxyRoutes _hls;
  late final ProxyItems _items;
  final _open = ProxyOpenAnswers();
  late final LoopbackListener _listener;
  bool _closed = false;

  /// The proxy URL of [ref]'s item. Begins a new playthrough of it (the
  /// player asks once per play); starts the server the first time.
  Future<String> urlFor(RemoteSourceRef ref) async {
    if (_closed) throw StateError('stream proxy closed');
    final server = await _listener.bind();
    _items.begin(ref);
    return _entryUrl(
      server.port,
      RemoteStreamKind.sourcePlugin,
      ref.installId,
      ref.itemId,
    );
  }

  String _entryUrl(
    int port,
    RemoteStreamKind kind,
    String installId,
    String itemId,
  ) =>
      'http://127.0.0.1:$port/${_token.value}/${kind.segment}/'
      '$installId/${Uri.encodeComponent(itemId)}';

  /// The format of the current resolve of [url], an entry URL this server
  /// handed out: waits for the resolve (shared with the requests, started if
  /// need be). Null when [url] is not an entry URL of this server with a kept
  /// playthrough of a plugin that was not dropped, when the resolve fails, or
  /// after the format deadline ([formatOfTimeout]). Never throws.
  Future<RemoteStreamFormat?> formatOf(String url) async {
    try {
      final started = _listener.started;
      final uri = Uri.tryParse(url);
      if (started == null || uri == null || _closed) return null;
      final server = await started;
      final segments = uri.pathSegments;
      if (uri.scheme != 'http' ||
          uri.host != '127.0.0.1' ||
          uri.port != server.port ||
          segments.length != 4 ||
          !_token.matches(segments[0])) {
        return null;
      }
      final kept = _items.kept(segments);
      if (kept == null) return null;
      return await _hls.formatOf(kept.playthrough, () => _isGone(kept.owner));
    } on Object {
      return null;
    }
  }

  /// Why the last resolve of [ref]'s item failed, or null (no URL in it).
  Object? lastFailureOf(RemoteSourceRef ref) => _items.failureOf(ref);

  /// Ends [installId]'s open responses, forgets its playthroughs, answers
  /// 404 for its items from now on, then tells the drop listeners.
  @override
  void dropPlugin(String installId) {
    if (_closed || !_items.markDropped(installId)) return;
    _open.abortOwner(installId);
    _items.endOwner(installId);
    _log.info('$installId dropped');
    _onDrop(installId);
  }

  /// Serves [installId]'s items again (from their next [urlFor]).
  @override
  void restorePlugin(String installId) => _items.restore(installId);

  /// Stops the server and every open response.
  Future<void> close() async {
    _closed = true;
    _open.abortAll();
    _items.clear();
    _client.close(force: true);
    await _listener.close();
  }

  Future<Response> _handle(Request request) async {
    try {
      return await _serve(request);
    } on Object {
      return Response(HttpStatus.badGateway);
    }
  }

  Future<Response> _serve(Request request) async {
    final server = await _listener.started;
    if (server == null ||
        request.headers['host'] != '127.0.0.1:${server.port}') {
      return Response(HttpStatus.notFound);
    }
    if (request.method != 'GET') return Response(HttpStatus.methodNotAllowed);
    final segments = request.requestedUri.pathSegments;
    final isEntry = segments.length == 4;
    if ((!isEntry && segments.length != 7) || !_token.matches(segments[0])) {
      return Response(HttpStatus.notFound);
    }
    final resource = !isEntry && segments[4] == 'hls'
        ? parseHlsResourceName(segments.skip(4).join('/'))
        : null;
    if (!isEntry && resource == null) return Response(HttpStatus.notFound);
    final kept = _items.kept(segments);
    if (kept == null) return Response(HttpStatus.notFound);
    final (:kind, :owner, :playthrough) = kept;
    final range = RangeRequest.parse(request.headers['range']);
    if (resource != null) {
      final answer = await _hls.open(playthrough, resource, range);
      return _respond(owner, playthrough, answer, 'hls ${resource.kind.name}');
    }
    final entry = _entryUrl(server.port, kind, segments[2], segments[3]);
    final page = await _hls.entry(
      playthrough,
      entry,
      gone: () => _isGone(owner),
    );
    if (page != null) return page;
    final answer = await _reader.open(playthrough, range);
    return _respond(owner, playthrough, answer, '');
  }

  bool _isGone(String owner) => _items.isDropped(owner) || _closed;

  Response _respond(
    String owner,
    Playthrough playthrough,
    ProxyAnswer answer,
    String what,
  ) => _open.respond(owner, playthrough, answer, what, gone: _isGone(owner));
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
