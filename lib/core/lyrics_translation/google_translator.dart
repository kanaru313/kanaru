import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'lyrics_translator.dart';
import 'translation_failure.dart';
import 'translation_http.dart';
import 'translation_language.dart';
import 'translation_lines.dart';
import 'translation_service.dart';

final _log = Logger('translation');

final _googleBase = Uri.parse('https://translate.googleapis.com');

const _maxItemsPerRequest = 50;
const _maxCharsPerRequest = 4000;

/// Translates with Google's public `translate_a/t` web endpoint: one `q` per
/// line in a form POST, one `[translation, detectedLanguage]` per line back.
/// It needs no key but is unofficial: Google may answer 429 or a web page when
/// it dislikes the caller, which surfaces as `blocked`.
///
/// Requests go out one after another, once each: no retry, no cooldown. The
/// caller decides when to try again.
class GoogleTranslator implements LyricsTranslator {
  GoogleTranslator(
    this._client, {
    Uri? baseUri,
    this.requestTimeout = translationRequestTimeout,
  }) : _base = baseUri ?? _googleBase;

  final HttpClient _client;
  final Uri _base;
  final Duration requestTimeout;

  @override
  LyricsTranslationService get service => LyricsTranslationService.google;

  @override
  bool supports(TranslationLanguage language) => true;

  /// [context] is ignored: this endpoint has no way to take it.
  @override
  Future<TranslatedLines> translate(
    List<String> lines,
    TranslationLanguage target, {
    String? context,
  }) async {
    final texts = <String>[];
    final detected = <String?>[];
    final chunks = chunkLines(
      lines,
      maxItems: _maxItemsPerRequest,
      maxChars: _maxCharsPerRequest,
    );
    for (final chunk in chunks) {
      final part = await _translateChunk(chunk, target);
      texts.addAll(part.texts);
      detected.addAll(part.detected);
    }
    return TranslatedLines(texts, detected);
  }

  Future<TranslatedLines> _translateChunk(
    List<String> chunk,
    TranslationLanguage target,
  ) async {
    final uri = _base.replace(
      path: '/translate_a/t',
      queryParameters: {
        'client': 'gtx',
        'sl': 'auto',
        'tl': target.googleCode,
        'dt': 't',
        'ie': 'UTF-8',
        'oe': 'UTF-8',
      },
    );
    final TranslationResponse response;
    try {
      response = await sendTranslationRequest(
        _client,
        method: 'POST',
        uri: uri,
        headers: const {
          'content-type': 'application/x-www-form-urlencoded;charset=UTF-8',
        },
        body: chunk.map((l) => 'q=${Uri.encodeQueryComponent(l)}').join('&'),
        requestTimeout: requestTimeout,
      );
    } on TranslationException catch (e) {
      _log.warning('google request failed: ${e.kind.name}');
      rethrow;
    }
    try {
      _checkStatus(response.status);
      return parseGoogleResponse(response.body, chunk.length);
    } on TranslationException catch (e) {
      _log.warning('google failed: ${e.kind.name} HTTP ${response.status}');
      rethrow;
    }
  }
}

void _checkStatus(int status) {
  if (status == 429 || status == 403 || (status >= 300 && status < 400)) {
    throw TranslationException(
      TranslationFailureKind.blocked,
      statusCode: status,
    );
  }
  if (status >= 500) {
    throw TranslationException(
      TranslationFailureKind.server,
      statusCode: status,
    );
  }
  if (status < 200 || status >= 300) {
    throw TranslationException(
      TranslationFailureKind.invalidResponse,
      statusCode: status,
    );
  }
}

/// Reads an answer to [count] `q` values. Accepts a list of
/// `[translation, language]` pairs, a list of bare strings, and for a single
/// `q` the flattened `[translation, language]`. Anything else, or a different
/// number of results, is `invalidResponse`; a web page (starts with `<`) is
/// `blocked`.
TranslatedLines parseGoogleResponse(String body, int count) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    throw TranslationException(
      body.trimLeft().startsWith('<')
          ? TranslationFailureKind.blocked
          : TranslationFailureKind.invalidResponse,
    );
  }
  if (json is! List) {
    throw const TranslationException(TranslationFailureKind.invalidResponse);
  }
  final flattened =
      count == 1 && json.length == 2 && json.every((e) => e is String);
  final items = flattened ? [json] : json;
  if (items.length != count) {
    throw const TranslationException(TranslationFailureKind.invalidResponse);
  }
  final texts = <String>[];
  final detected = <String?>[];
  for (final item in items) {
    if (item is String) {
      texts.add(item);
      detected.add(null);
    } else if (item is List && item.isNotEmpty && item.first is String) {
      texts.add(item.first as String);
      final language = item.length > 1 ? item[1] : null;
      detected.add(language is String && language.isNotEmpty ? language : null);
    } else {
      throw const TranslationException(TranslationFailureKind.invalidResponse);
    }
  }
  return TranslatedLines(texts, detected);
}
