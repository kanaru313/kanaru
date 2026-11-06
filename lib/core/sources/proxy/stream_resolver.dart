import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'source_plugin_stream_resolver.dart';

/// The kinds of remote audio the stream proxy serves; [segment] is the
/// kind's part of the proxy URL. A future storage backend adds a kind.
enum RemoteStreamKind {
  sourcePlugin('source-plugin');

  const RemoteStreamKind(this.segment);

  /// The URL path segment of this kind.
  final String segment;

  /// The kind whose [segment] is [value], or null.
  static RemoteStreamKind? fromSegment(String value) {
    for (final kind in values) {
      if (kind.segment == value) return kind;
    }
    return null;
  }
}

/// Where the bytes of one item are, as a [TrackStreamResolver] found them.
/// Never logged: [url] and [headers] may hold a signature or a cookie.
class ResolvedStream {
  const ResolvedStream({
    required this.url,
    required this.headers,
    required this.allowed,
    this.mimeType,
    this.expiresAt,
  });

  /// Already checked by the resolver; the proxy fetches it as it is.
  final Uri url;

  /// Sent with every upstream request for [url].
  final Map<String, String> headers;

  /// The type the resolver reported, unchecked; the proxy sends it only
  /// when it has the shape of a media type.
  final String? mimeType;

  /// When [url] stops working; null when unknown.
  final DateTime? expiresAt;

  /// Asked before every upstream request: false once the user withdrew the
  /// consent that let this stream be fetched.
  final bool Function() allowed;
}

/// Why a resolve gave nothing. Carries no URL.
class ResolveFailure implements Exception {
  const ResolveFailure(this.reason);

  /// For the log: a fixed word, never a URL or a plugin message.
  final String reason;

  @override
  String toString() => 'ResolveFailure($reason)';
}

/// Finds the upstream stream of an item of one [RemoteStreamKind].
abstract interface class TrackStreamResolver {
  /// The owner of [key] (for a source plugin, its install id), or null when
  /// [key] is malformed. The proxy stops an owner's streams on a drop.
  String? ownerOf(String key);

  /// Resolves [key]. [fresh] asks the resolver to skip any cache of its own
  /// (the last URL was refused). Once [abandoned] returns true nothing more
  /// should be sent. Throws [ResolveFailure].
  Future<ResolvedStream> resolve(
    String key, {
    required bool fresh,
    required bool Function() abandoned,
  });
}

/// The resolver of each kind. The stream proxy reads it once, when it is
/// created; tests override it.
final trackStreamResolversProvider =
    Provider<Map<RemoteStreamKind, TrackStreamResolver>>(
      (ref) => {
        RemoteStreamKind.sourcePlugin: sourcePluginStreamResolverFor(ref),
      },
    );
