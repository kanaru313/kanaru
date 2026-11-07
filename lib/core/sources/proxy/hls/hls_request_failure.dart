/// Why a request for an HLS sub-resource failed although upstream answered
/// well enough: the proxy answers `502`.
enum HlsRequestFailureKind {
  /// A key whose body is not exactly 16 bytes.
  badKey,

  /// The request names a snapshot whose layout differs from the current one
  /// of the same item: segment i of the old playlist is not segment i of the
  /// new one.
  layoutChanged,
}

/// A request-time failure that is not an HTTP status. Only [kind] is logged
/// (`hls <kind>`), never a URL.
class HlsRequestFailure implements Exception {
  const HlsRequestFailure(this.kind);

  final HlsRequestFailureKind kind;

  /// For the log: a fixed phrase.
  String get reason => 'hls ${kind.name}';

  @override
  String toString() => 'HlsRequestFailure($reason)';
}
