/// Why a translation request failed.
enum TranslationFailureKind {
  network,
  noKey,
  badKey,
  quotaExceeded,
  rateLimited,
  blocked,
  unsupportedLanguage,
  tooLong,
  server,
  invalidResponse,
  emptyResult,
  keyStoreLocked,
  keyStoreUnavailable,
}

/// A failed translation request. Carries only the [kind] and the HTTP
/// [statusCode], never the request text or the API key, so it is safe to log.
class TranslationException implements Exception {
  const TranslationException(this.kind, {this.statusCode});

  final TranslationFailureKind kind;
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'TranslationException(${kind.name})'
      : 'TranslationException(${kind.name}, HTTP $statusCode)';
}
