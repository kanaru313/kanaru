import 'dart:convert';

import 'package:logging/logging.dart';

import '../database/library_database.dart';
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

  final LyricsTranslationService service;
  final String targetLang;
  final String? sourceLang;

  /// Source line to translation; unmodifiable.
  final Map<String, String> lines;
}

/// Decodes [row]; null for an unknown provider, invalid JSON or a value that
/// is not a string-to-string object. Each null result goes through one
/// warning per run (provider and language only, never content).
CachedTranslation? decodeTranslationRow(LyricTranslationRow row) {
  final service = LyricsTranslationService.values
      .where((s) => s.name == row.provider)
      .firstOrNull;
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
({CachedTranslation? current, CachedTranslation? other}) pickCached(
  List<CachedTranslation> cached,
  LyricsTranslationService preferred,
) {
  CachedTranslation? current;
  CachedTranslation? other;
  for (final c in cached) {
    if (c.service == preferred) {
      current ??= c;
    } else {
      other ??= c;
    }
  }
  return (current: current, other: other);
}
