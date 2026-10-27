import 'dart:convert';
import 'dart:io';

import 'deepl_api.dart';
import 'lyrics_translator.dart';
import 'translation_failure.dart';
import 'translation_http.dart';
import 'translation_language.dart';
import 'translation_service.dart';

const _maxItemsPerRequest = 50;
const _maxBodyBytes = 100 * 1024;
const _maxContextChars = 4000;

/// Translates with the DeepL API (free or paid, picked by the key). Chunks go
/// out one after another, once each: no retry, because DeepL bills a sent
/// chunk and the caller decides when to try again.
class DeepLTranslator implements LyricsTranslator {
  /// [apiKey] is checked when translating: a key that cannot be one fails
  /// [translate] with `badKey` before any request.
  DeepLTranslator(
    this._client,
    this._rawKey, {
    Uri? baseUri,
    this.requestTimeout = translationRequestTimeout,
  }) : _baseOverride = baseUri;

  final HttpClient _client;
  final String _rawKey;
  final Uri? _baseOverride;
  final Duration requestTimeout;

  @override
  LyricsTranslationService get service => LyricsTranslationService.deepl;

  @override
  bool supports(TranslationLanguage language) => language.deeplCode != null;

  /// [context] (default: all [lines]) is sent as DeepL's `context`, which
  /// improves the result and is not billed. Cut at 4000 characters.
  @override
  Future<TranslatedLines> translate(
    List<String> lines,
    TranslationLanguage target, {
    String? context,
  }) async {
    final key = normalizeDeepLKey(_rawKey);
    final code = target.deeplCode;
    if (code == null) {
      throw const TranslationException(
        TranslationFailureKind.unsupportedLanguage,
      );
    }
    final contextText = _cut(context ?? lines.join('\n'));
    final texts = <String>[];
    final detected = <String?>[];
    for (final chunk in _chunk(lines, code, contextText)) {
      final part = await _translateChunk(key, chunk, code, contextText);
      texts.addAll(part.texts);
      detected.addAll(part.detected);
    }
    return TranslatedLines(texts, detected);
  }

  Future<TranslatedLines> _translateChunk(
    String key,
    List<String> chunk,
    String targetCode,
    String context,
  ) async {
    final base = _baseOverride ?? deeplBaseFor(key);
    TranslationResponse? response;
    try {
      response = await sendTranslationRequest(
        _client,
        method: 'POST',
        uri: base.replace(path: '/v2/translate'),
        headers: deeplHeaders(key, json: true),
        body: _body(chunk, targetCode, context),
        requestTimeout: requestTimeout,
      );
      checkDeepLStatus(response);
      return parseDeepLResponse(response.body, chunk.length);
    } on TranslationException catch (e) {
      logDeepLFailure('translate', e, response?.headers);
      rethrow;
    }
  }
}

String _body(List<String> texts, String targetCode, String context) =>
    jsonEncode({
      'text': texts,
      'target_lang': targetCode,
      'split_sentences': '0',
      'preserve_formatting': true,
      if (context.isNotEmpty) 'context': context,
    });

String _cut(String text) {
  if (text.length <= _maxContextChars) return text;
  var end = _maxContextChars;
  final last = text.codeUnitAt(end - 1);
  if (last >= 0xd800 && last <= 0xdbff) end--; // Not half a surrogate pair.
  return text.substring(0, end);
}

/// Chunks of at most 50 texts whose request body stays under 100 KiB. The
/// size is exact: the body is the fixed part plus each text's JSON form. A
/// text too large for a body alone is its own chunk and DeepL answers 413.
List<List<String>> _chunk(List<String> lines, String targetCode, String ctx) {
  final fixed = utf8.encode(_body(const [], targetCode, ctx)).length;
  final chunks = <List<String>>[];
  var current = <String>[];
  var bytes = fixed;
  for (final line in lines) {
    final size = utf8.encode(jsonEncode(line)).length + 1; // + comma
    if (current.isNotEmpty &&
        (current.length >= _maxItemsPerRequest ||
            bytes + size > _maxBodyBytes)) {
      chunks.add(current);
      current = <String>[];
      bytes = fixed;
    }
    current.add(line);
    bytes += size;
  }
  if (current.isNotEmpty) chunks.add(current);
  return chunks;
}

/// Reads `{"translations": [{"text", "detected_source_language"}, ...]}` with
/// exactly [count] entries; the detected language is lower-cased.
TranslatedLines parseDeepLResponse(String body, int count) {
  const bad = TranslationException(TranslationFailureKind.invalidResponse);
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    throw bad;
  }
  final list = json is Map ? json['translations'] : null;
  if (list is! List || list.length != count) throw bad;
  final texts = <String>[];
  final detected = <String?>[];
  for (final item in list) {
    final text = item is Map ? item['text'] : null;
    if (text is! String) throw bad;
    texts.add(text);
    final language = (item as Map)['detected_source_language'];
    detected.add(
      language is String && language.isNotEmpty ? language.toLowerCase() : null,
    );
  }
  return TranslatedLines(texts, detected);
}
