import 'package:drift/drift.dart' show Value;

import '../database/library_database.dart';
import '../database/lyric_translation_queries.dart';
import 'lyrics_translator.dart';
import 'translation_cache.dart';
import 'translation_failure.dart';
import 'translation_language.dart';
import 'translation_lines.dart';
import 'translation_service.dart';
import 'translation_song_context.dart';

/// What chunks already translated in this session, by source line.
class JobPartial {
  JobPartial([this.version]);

  /// The `updatedAt` of the plugin record the chunks came from; a different
  /// value (the plugin was updated) makes them unusable.
  final int? version;

  final texts = <String, String>{};
  final detected = <String, String?>{};
}

/// Throws `tooLong` or `unsupportedLanguage` when the job must not be sent:
/// too much text, more chunks than the translator allows, or a language it
/// cannot translate into.
void checkJobLimits(
  List<String> lines,
  TranslationLanguage target,
  LyricsTranslator translator,
) {
  final chars = lines.fold<int>(0, (sum, line) => sum + line.length);
  if (lines.length > maxTranslatedLines || chars > maxTranslatedChars) {
    throw const TranslationException(TranslationFailureKind.tooLong);
  }
  final maxChunks = translator.chunkLimits.maxChunks;
  if (maxChunks != null &&
      chunkLines(
            lines,
            maxItems: translator.chunkLimits.maxLines,
            maxChars: translator.chunkLimits.maxChars,
          ).length >
          maxChunks) {
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
  JobPartial partial, {
  TranslationSongContext? song,
}) async {
  final limits = translator.chunkLimits;
  final missing = [
    for (final line in lines)
      if (!partial.texts.containsKey(line)) line,
  ];
  final chunks = chunkLines(
    missing,
    maxItems: limits.maxLines,
    maxChars: limits.maxChars,
  );
  for (final chunk in chunks) {
    final part = await translator.translate(chunk, target, song: song);
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
  TranslationServiceId service,
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
      provider: service.value,
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
