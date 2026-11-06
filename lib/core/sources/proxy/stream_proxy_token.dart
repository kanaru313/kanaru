import 'dart:convert';
import 'dart:math';

/// The proxy's session token: 32 random bytes in base64url without
/// padding, the first path segment of every proxy URL.
class StreamProxyToken {
  StreamProxyToken(Random random)
    : value = base64Url
          .encode([for (var i = 0; i < 32; i++) random.nextInt(256)])
          .replaceAll('=', '');

  final String value;

  late final List<int> _bytes = utf8.encode(value);

  /// Whether [given] is the token. Takes the same time wherever the first
  /// difference is, so a guess learns nothing from the timing.
  bool matches(String given) {
    final other = utf8.encode(given);
    var diff = other.length ^ _bytes.length;
    for (var i = 0; i < _bytes.length; i++) {
      diff |= _bytes[i] ^ (i < other.length ? other[i] : 0);
    }
    return diff == 0;
  }
}
