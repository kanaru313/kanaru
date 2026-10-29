/// Why an online lyrics request failed.
enum LyricsFetchKind {
  /// No connection, TLS failure, broken stream or timeout.
  network,

  /// The service answered with an error status that is not a rate limit.
  server,

  /// The service asked to slow down (429 or 503).
  rateLimited,

  /// The answer is not what the service documents: wrong content type,
  /// malformed JSON, wrong shape, body too large, or an unlisted 404.
  invalidResponse,

  /// The request address is not one of the provider's registered hosts, is
  /// not `https`, or names a port. Nothing was sent.
  blockedHost,

  /// The user has not agreed to send requests to this provider. Nothing was
  /// sent.
  notConsented,
}

/// Shortest and longest wait a service may ask for.
const minRetryAfter = Duration(seconds: 1);
const maxRetryAfter = Duration(minutes: 15);

/// A failed online lyrics request. Carries only the [kind] and the wait the
/// service asked for, never the address, the query or a body, so it is safe
/// to log.
class LyricsFetchException implements Exception {
  const LyricsFetchException(this.kind, {this.retryAfter});

  final LyricsFetchKind kind;

  /// The wait asked for by a `Retry-After` header in whole seconds, between
  /// [minRetryAfter] and [maxRetryAfter]; `null` when there was none.
  final Duration? retryAfter;

  @override
  String toString() => 'LyricsFetchException(${kind.name})';
}

final _digits = RegExp(r'^\d+$');

/// Reads a `Retry-After` header as integer seconds, clamped to
/// [minRetryAfter]..[maxRetryAfter]. An HTTP date or any other text gives
/// `null`.
Duration? parseRetryAfter(String? header) {
  final text = header?.trim();
  if (text == null || !_digits.hasMatch(text)) return null;
  // More digits than an int holds is still "very long".
  final seconds = int.tryParse(text);
  if (seconds == null || seconds >= maxRetryAfter.inSeconds) {
    return maxRetryAfter;
  }
  final wait = Duration(seconds: seconds);
  return wait < minRetryAfter ? minRetryAfter : wait;
}
