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
  });

  final TranslationServiceId service;
  final String targetLang;
  final String? sourceLang;

  /// Source line to translation; unmodifiable.
  final Map<String, String> lines;
}

/// Decodes [row]; null for a provider that is neither `google` nor a plugin
/// id (old `deepl` rows included), invalid JSON or a value that
/// is not a string-to-string object. Each null result goes through one
/// warning per run (provider and language only, never content).
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

/// Splits [cached] into the [preferred] service's translation and any other
/// service's, so the caller can offer the other as a fallback.
///
/// Another service's row is offered only when it is Google or one of
/// [knownPlugins] (every translate plugin that has a record, removed ones
/// included: their rows are kept and named by the record), and never when
/// it says the lyrics are already in [target]: that verdict of one service
/// must not stop a request to the one the user picked.
({CachedTranslation? current, CachedTranslation? other}) pickCached(
  List<CachedTranslation> cached,
  TranslationServiceId preferred, {
  Set<TranslationServiceId> knownPlugins = const {},
  TranslationLanguage? target,
}) {
  CachedTranslation? current;
  CachedTranslation? other;
  for (final c in cached) {
    if (c.service == preferred) {
      current ??= c;
    } else if (c.service.isGoogle || knownPlugins.contains(c.service)) {
      if (target != null && isSameLanguage(c.sourceLang, target)) continue;
      other ??= c;
    }
  }
  return (current: current, other: other);
}
