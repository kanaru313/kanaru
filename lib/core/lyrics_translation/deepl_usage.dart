import 'dart:convert';
import 'dart:io';

import 'deepl_api.dart';
import 'translation_failure.dart';
import 'translation_http.dart';

/// How much of the monthly DeepL quota is used. [freeKey] tells the free plan
/// (key ends in `:fx`) from a paid one.
class DeepLUsage {
  const DeepLUsage({
    required this.characterCount,
    required this.characterLimit,
    required this.freeKey,
  });

  final int characterCount;
  final int characterLimit;
  final bool freeKey;
}

/// Asks DeepL for the usage of [key]. Throws [TranslationException] with the
/// same kinds as translating: `badKey` (also for a key that cannot be one,
/// without any request), `network`, `server` and so on.
Future<DeepLUsage> fetchDeepLUsage(
  HttpClient client,
  String key, {
  Uri? baseUri,
  Duration requestTimeout = translationRequestTimeout,
}) async {
  final normalized = normalizeDeepLKey(key);
  TranslationResponse? response;
  try {
    response = await sendTranslationRequest(
      client,
      method: 'GET',
      uri: (baseUri ?? deeplBaseFor(normalized)).replace(path: '/v2/usage'),
      headers: deeplHeaders(normalized),
      requestTimeout: requestTimeout,
    );
    checkDeepLStatus(response);
    return _parse(response.body, normalized.endsWith(':fx'));
  } on TranslationException catch (e) {
    logDeepLFailure('usage', e, response?.headers);
    rethrow;
  }
}

DeepLUsage _parse(String body, bool freeKey) {
  const bad = TranslationException(TranslationFailureKind.invalidResponse);
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    throw bad;
  }
  final count = json is Map ? json['character_count'] : null;
  final limit = json is Map ? json['character_limit'] : null;
  if (count is! num || limit is! num) throw bad;
  return DeepLUsage(
    characterCount: count.toInt(),
    characterLimit: limit.toInt(),
    freeKey: freeKey,
  );
}
