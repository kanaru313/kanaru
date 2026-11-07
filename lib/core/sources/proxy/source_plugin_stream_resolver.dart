import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lyrics/online/plugin_host_patterns.dart';
import '../../lyrics/plugins/store/plugin_install_id.dart';
import '../../settings/settings_provider.dart';
import '../source_plugin_records.dart';
import '../source_plugin_runner.dart';
import 'stream_resolver.dart';

/// A source plugin's `stream.js`, as `SourcePluginRunner.stream` runs it.
typedef SourceStreamCall = Future<SourceStream> Function(
  String installId,
  String itemId, {
  required bool fresh,
  required bool Function() abandoned,
});

/// Whether the proxy may fetch [url] for a plugin allowed to reach [hosts]:
/// `https`, no explicit port, no user info (the rules of a plugin's own
/// `fetch`), and a host the plugin declared (wildcards included). Where the
/// connection then goes is checked again by the public-only connector.
bool sourceStreamUrlAllowed(Uri url, PluginHostSet hosts) =>
    url.isAbsolute &&
    url.scheme == 'https' &&
    !url.hasPort &&
    url.userInfo.isEmpty &&
    hosts.allows(url.host);

/// Resolves the items of source plugins. A key is
/// `<installId>/<itemId>`: the install id is a plugin id, the item id is
/// not empty and may hold `/`.
///
/// A resolve runs the plugin's `stream.js` and accepts the URL only when
/// [sourceStreamUrlAllowed] does with the plugin's declared hosts. The
/// stream's `allowed` asks the plugin's consent live.
class SourcePluginStreamResolver implements TrackStreamResolver {
  SourcePluginStreamResolver({
    required this._stream,
    required this._hostsOf,
    required this._consented,
  });

  final SourceStreamCall _stream;

  /// The declared hosts of an enabled source plugin, or null when it is not
  /// one (not installed, removed, of another kind, or not read yet).
  final List<String>? Function(String installId) _hostsOf;
  final bool Function(String installId) _consented;

  @override
  String? ownerOf(String key) => _split(key)?.installId;

  @override
  Future<ResolvedStream> resolve(
    String key, {
    required bool fresh,
    required bool Function() abandoned,
  }) async {
    final parts = _split(key);
    if (parts == null) throw const ResolveFailure('malformed key');
    final (:installId, :itemId) = parts;
    final hosts = _hostsOf(installId);
    if (hosts == null) throw const ResolveFailure('no such source plugin');
    final SourceStream stream;
    try {
      stream = await _stream(
        installId,
        itemId,
        fresh: fresh,
        abandoned: abandoned,
      );
    } on SourceFailure catch (e) {
      throw ResolveFailure(e.kind.name);
    }
    final allowedHosts = PluginHostSet(hosts);
    if (!sourceStreamUrlAllowed(stream.url, allowedHosts)) {
      throw const ResolveFailure('blockedHost');
    }
    return ResolvedStream(
      url: stream.url,
      headers: stream.headers,
      mimeType: stream.mimeType,
      expiresAt: stream.expiresAt,
      allowed: () => _consented(installId),
      redirectAllowed: (url) => sourceStreamUrlAllowed(url, allowedHosts),
    );
  }

  static ({String installId, String itemId})? _split(String key) {
    final slash = key.indexOf('/');
    if (slash < 0) return null;
    final installId = key.substring(0, slash);
    final itemId = key.substring(slash + 1);
    if (!pluginInstallIdPattern.hasMatch(installId) || itemId.isEmpty) {
      return null;
    }
    return (installId: installId, itemId: itemId);
  }
}

/// The app's source plugin resolver: the runner, the records and the
/// consent are read on each call, never watched. Fails closed when this
/// container is gone.
SourcePluginStreamResolver sourcePluginStreamResolverFor(Ref ref) =>
    SourcePluginStreamResolver(
      stream: (installId, itemId, {required fresh, required abandoned}) {
        final SourcePluginRunner? runner;
        try {
          runner = ref.read(sourcePluginRunnerProvider);
        } on Object {
          throw const SourceFailure(kind: SourceFailureKind.skipped);
        }
        if (runner == null) {
          throw const SourceFailure(kind: SourceFailureKind.skipped);
        }
        return runner.stream(
          installId,
          itemId,
          fresh: fresh,
          abandoned: abandoned,
        );
      },
      hostsOf: (installId) {
        try {
          final records = ref.read(sourcePluginRecordsProvider).value;
          for (final record in records ?? const <LyricsPluginRecord>[]) {
            if (record.installId == installId) return record.hosts;
          }
        } on Object {
          // The container is gone: no plugin.
        }
        return null;
      },
      consented: (installId) {
        try {
          return ref.read(settingsProvider).onlineSources.allows(installId);
        } on Object {
          return false;
        }
      },
    );
