import '../../remote_source_ref.dart';
import '../resolved_streams.dart';
import '../stream_resolver.dart';

/// The items the stream proxy can serve: which plugin owns each, its
/// playthroughs, and which plugins were dropped (uninstalled or consent
/// withdrawn) and so are answered 404 until restored.
class ProxyItems {
  ProxyItems(this._resolvers, this._streams);

  final Map<RemoteStreamKind, TrackStreamResolver> _resolvers;
  final Map<RemoteStreamKind, ResolvedStreams> _streams;
  final _dropped = <String>{};

  /// The plugin was dropped and not restored.
  bool isDropped(String installId) => _dropped.contains(installId);

  /// Begins a new playthrough of [ref]'s item, unless its plugin is unknown
  /// or dropped.
  void begin(RemoteSourceRef ref) {
    const kind = RemoteStreamKind.sourcePlugin;
    final key = '${ref.installId}/${ref.itemId}';
    final owner = _resolvers[kind]?.ownerOf(key);
    if (owner != null && !isDropped(owner)) _streams[kind]?.begin(key, owner);
  }

  /// The owner and kept playthrough of the item named by [segments]
  /// (`<token>/<kind>/<installId>/<itemId>...`), or null when the kind or the
  /// item is unknown, the owner was dropped or the playthrough was forgotten.
  ({RemoteStreamKind kind, String owner, Playthrough playthrough})? kept(
    List<String> segments,
  ) {
    final kind = RemoteStreamKind.fromSegment(segments[1]);
    if (kind == null) return null;
    final key = '${segments[2]}/${segments[3]}';
    final owner = _resolvers[kind]?.ownerOf(key);
    if (owner == null || isDropped(owner)) return null;
    final playthrough = _streams[kind]?.lookup(key);
    if (playthrough == null) return null;
    return (kind: kind, owner: owner, playthrough: playthrough);
  }

  /// Why the last resolve of [ref]'s item failed, or null when it has not or
  /// the item has no kept playthrough.
  Object? failureOf(RemoteSourceRef ref) =>
      _streams[RemoteStreamKind.sourcePlugin]
          ?.lookup('${ref.installId}/${ref.itemId}')
          ?.failure;

  /// Marks [installId] dropped; false when it already was.
  bool markDropped(String installId) => _dropped.add(installId);

  /// Serves [installId]'s items again (from their next [begin]).
  void restore(String installId) => _dropped.remove(installId);

  /// Ends and forgets [installId]'s playthroughs.
  void endOwner(String installId) {
    for (final streams in _streams.values) {
      streams.dropOwner(installId);
    }
  }

  /// Ends and forgets every playthrough.
  void clear() {
    for (final streams in _streams.values) {
      streams.clear();
    }
  }
}
