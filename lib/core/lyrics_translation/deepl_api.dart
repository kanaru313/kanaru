import 'package:logging/logging.dart';

import 'translation_failure.dart';
import 'translation_http.dart';

final _log = Logger('translation');

final _traceId = RegExp(r'^[\w-]{1,64}$');

/// A key as DeepL issues it is 36 characters (`:fx` adds 3); the bounds leave
/// room without letting a pasted paragraph through.
final _plausibleKey = RegExp(r'^[\x21-\x7e]{20,128}$');

/// [raw] without surrounding whitespace, or `badKey` when what is left cannot
/// be a key: inner whitespace, control or non-ASCII characters, or a length
/// outside 20..128. Nothing is sent for such a key, and the error carries
/// none of its text.
String normalizeDeepLKey(String raw) {
  final key = raw.trim();
  if (!_plausibleKey.hasMatch(key)) {
    throw const TranslationException(TranslationFailureKind.badKey);
  }
  return key;
}

/// Free keys end in `:fx` and use a different host from paid ones.
Uri deeplBaseFor(String key) => Uri.parse(
  key.endsWith(':fx') ? 'https://api-free.deepl.com' : 'https://api.deepl.com',
);

/// The header map of a DeepL call. [key] must be normalized already.
Map<String, String> deeplHeaders(String key, {bool json = false}) => {
  'authorization': 'DeepL-Auth-Key $key',
  if (json) 'content-type': 'application/json',
};

/// Throws the failure DeepL's [status] stands for; returns on 2xx.
void checkDeepLStatus(TranslationResponse response) {
  final status = response.status;
  if (status >= 200 && status < 300) return;
  final kind = switch (status) {
    401 || 403 => TranslationFailureKind.badKey,
    456 => TranslationFailureKind.quotaExceeded,
    429 || 529 => TranslationFailureKind.rateLimited,
    >= 500 => TranslationFailureKind.server,
    // 413 means a chunk was too large, which is a bug here, not the user's.
    _ => TranslationFailureKind.invalidResponse,
  };
  throw TranslationException(kind, statusCode: status);
}

/// Logs a failed DeepL call: service, status, kind and DeepL's trace id only.
void logDeepLFailure(
  String call,
  TranslationException e,
  Map<String, String>? headers,
) {
  final raw = headers?['x-trace-id'];
  // The id is echoed from the network: log it only when it looks like one.
  final trace = raw != null && _traceId.hasMatch(raw) ? raw : null;
  _log.warning(
    'deepl $call failed: ${e.kind.name}'
    '${e.statusCode == null ? '' : ' HTTP ${e.statusCode}'}'
    '${trace == null ? '' : ' trace $trace'}',
  );
}
