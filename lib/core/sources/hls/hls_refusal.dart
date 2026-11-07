/// Why a playlist (or the stream it belongs to) is refused. The name is what
/// logs show; it never carries a URL, a header or a token.
enum HlsRefusalKind {
  /// Not a playlist this app understands: bad syntax, bad number, bad
  /// duration or IV, no segment, `EXT-X-SKIP`, `EXT-X-DEFINE`, and so on.
  invalid,

  /// Over one of the size bounds in `hls_limits.dart`.
  tooLarge,

  /// A derived URL fails the stream's host rules. The parser never throws
  /// this one (it resolves URIs but does not judge hosts); the loader does.
  blockedHost,

  /// No `EXT-X-ENDLIST`: a live stream.
  live,

  /// DRM or any cipher other than `AES-128` with the identity key format.
  protected,

  /// Nothing to play as audio (video-only variants, I-frame-only playlist).
  noAudio,
}

/// Thrown by the playlist parser and variant choice for a playlist that must
/// not be played.
class HlsRefusal implements Exception {
  const HlsRefusal(this.kind);

  final HlsRefusalKind kind;

  @override
  String toString() => 'HlsRefusal(${kind.name})';
}
