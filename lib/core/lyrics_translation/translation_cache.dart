import 'dart:convert';

import 'package:logging/logging.dart';

import '../database/library_database.dart';
import 'translation_language.dart';
import 'translation_service.dart';

final _log = Logger('translation');
bool _warned = false;

/// A decoded `lyric_translations` row.
class CachedTranslation {
  const CachedTranslation({
    required this.service,
    required this.targetLang,
    required this.sourceLang,
    required this.lines,
    this.settingsJson,
  });

  final TranslationServiceId service;
  final String targetLang;
  final String? sourceLang;

  /// Source line to translation; unmodifiable.
  final Map<String, String> lines;

  /// The AI settings the version was made with (see `encodeAiSnapshot`);
  /// null for a plugin without them and for rows saved before they were kept.
  final String? settingsJson;
}

/// Decodes [row]; null for a provider that is not a plugin id (retired
/// built-in service rows included), invalid JSON or a value that is not a
/// string-to-string object. Each null result goes through one warning per run
/// (provider and language only, never content).
CachedTranslation? decodeTranslationRow(LyricTranslationRow row) {
  final service = TranslationServiceId.tryParse(row.provider);
  if (service != null) {
    try {
      final decoded = jsonDecode(row.linesJson);
      if (decoded is Map && decoded.values.every((v) => v is String)) {
        return CachedTranslation(
          service: service,
          targetLang: row.targetLang,
          sourceLang: row.sourceLang,
          lines: Map.unmodifiable(Map<String, String>.from(decoded)),
          settingsJson: row.settingsJson,
        );
      }
    } on FormatException {
      // Falls through to the warning below.
    }
  }
  if (!_warned) {
    _warned = true;
    _log.warning(
      'Ignoring unreadable cached translation '
      '(${row.provider}, ${row.targetLang})',
    );
  }
  return null;
}

/// The JSON stored in `lines_json`.
String encodeTranslationLines(Map<String, String> lines) => jsonEncode(lines);

/// Whether [row] records that the lyrics are already in its target language.
bool isSameLanguageRow(CachedTranslation row) {
  final target = translationLanguageFor(row.targetLang);
  return target != null && isSameLanguage(row.sourceLang, target);
}

/// Splits [cached] into the [preferred] service's translation and any other
/// service's, so the caller can offer the other as a fallback.
///
/// Every row in [cached] must be for one target language and already usable
/// (it has lines or says the lyrics are already in that language).
///
/// Another service's row is offered only when it is one of [knownPlugins]
/// (every translate plugin that has a record, removed ones included: their
/// rows are kept and named by the record). A row with translated lines comes
/// first. Failing that, a row saying the lyrics are already in the target
/// language is a fallback, but only from a plugin in [livePlugins] (still
/// installed): a removed plugin's verdict is not trusted. The [preferred]
/// service's own row always wins, so one service's "already in the target
/// language" never stops a request to the one the user picked.
({CachedTranslation? current, CachedTranslation? other}) pickCached(
  List<CachedTranslation> cached,
  TranslationServiceId preferred, {
  Set<TranslationServiceId> knownPlugins = const {},
  Set<TranslationServiceId> livePlugins = const {},
}) {
  CachedTranslation? current;
  CachedTranslation? withLines;
  CachedTranslation? sameLanguage;
  for (final c in cached) {
    if (c.service == preferred) {
      current ??= c;
    } else if (knownPlugins.contains(c.service)) {
      if (!isSameLanguageRow(c)) {
        withLines ??= c;
      } else if (livePlugins.contains(c.service)) {
        sameLanguage ??= c;
      }
    }
  }
  return (current: current, other: withLines ?? sameLanguage);
}
