import 'package:drift/drift.dart' show Value;

import '../database/library_database.dart';
import '../database/lyric_translation_queries.dart';
import 'lyrics_translator.dart';
import 'translation_cache.dart';
import 'translation_failure.dart';
import 'translation_language.dart';
import 'translation_lines.dart';
import 'translation_service.dart';

/// Lines per request; both services accept at least this much.
const _chunkItems = 50;
const _chunkChars = 4000;

/// What chunks already translated in this session, by source line.
class JobPartial {
  final texts = <String, String>{};
  final detected = <String, String?>{};
}

/// Throws `tooLong` or `unsupportedLanguage` when the job must not be sent.
void checkJobLimits(
  List<String> lines,
  TranslationLanguage target,
  LyricsTranslator translator,
) {
  final chars = lines.fold<int>(0, (sum, line) => sum + line.length);
  if (lines.length > maxTranslatedLines || chars > maxTranslatedChars) {
    throw const TranslationException(TranslationFailureKind.tooLong);
  }
  if (!translator.supports(target)) {
    throw const TranslationException(
      TranslationFailureKind.unsupportedLanguage,
    );
  }
}

Future<void> translateMissingLines(
  LyricsTranslator translator,
  List<String> lines,
  TranslationLanguage target,
  JobPartial partial,
) async {
  final missing = [
    for (final line in lines)
      if (!partial.texts.containsKey(line)) line,
  ];
  final chunks = chunkLines(
    missing,
    maxItems: _chunkItems,
    maxChars: _chunkChars,
  );
  for (final chunk in chunks) {
    final part = await translator.translate(chunk, target);
    if (part.texts.length != chunk.length ||
        part.detected.length != chunk.length) {
      throw const TranslationException(TranslationFailureKind.invalidResponse);
    }
    for (var i = 0; i < chunk.length; i++) {
      partial.texts[chunk[i]] = part.texts[i];
      partial.detected[chunk[i]] = part.detected[i];
    }
  }
}

/// Saves the result and returns the saved lines; null when there is nothing
/// worth saving.
Future<Map<String, String>?> saveJobResult(
  LibraryDatabase db,
  String hash,
  LyricsTranslationService service,
  List<String> lines,
  TranslationLanguage target,
  JobPartial partial,
) async {
  final map = <String, String>{};
  for (final line in lines) {
    final text = partial.texts[line]!;
    if (text.trim().isNotEmpty &&
        text.trim().toLowerCase() != line.trim().toLowerCase()) {
      map[line] = text;
    }
  }
  final source = dominantLanguage(lines, [
    for (final line in lines) partial.detected[line],
  ]);
  if (map.isEmpty && !isSameLanguage(source, target)) return null;
  await db.saveLyricTranslation(
    LyricTranslationsCompanion.insert(
      contentHash: hash,
      provider: service.name,
      targetLang: target.code,
      sourceLang: Value(source),
      linesJson: encodeTranslationLines(map),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
  );
  return map;
}

/// A number that is equal for equal [lines] whatever their order, so a view
/// can tell whether a row is the one a job saved without keeping the lines.
int linesFingerprint(Map<String, String> lines) => Object.hash(
  lines.length,
  Object.hashAllUnordered(
    lines.entries.map((e) => Object.hash(e.key, e.value)),
  ),
);
