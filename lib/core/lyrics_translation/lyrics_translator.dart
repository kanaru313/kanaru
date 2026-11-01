import 'translation_language.dart';
import 'translation_service.dart';
import 'translation_song_context.dart';

/// The result of translating a list of lines: [texts] and [detected] have the
/// same length as the input (implementations enforce this). [detected] holds
/// the source language reported per line, `null` when the service gave none.
class TranslatedLines {
  const TranslatedLines(this.texts, this.detected);

  final List<String> texts;
  final List<String?> detected;
}

/// How much one request of a translator may carry.
class TranslationChunkLimits {
  const TranslationChunkLimits({
    required this.maxLines,
    required this.maxChars,
    this.maxChunks,
  });

  final int maxLines;
  final int maxChars;

  /// Most chunks one job may need; a longer song is `tooLong`. `null` for no
  /// limit besides the job's own.
  final int? maxChunks;
}

/// One translation backend. A started job always runs to the end: there is no
/// cancellation, because a chunk is billed once sent and resending pays twice.
abstract interface class LyricsTranslator {
  TranslationServiceId get service;

  /// The size of the chunks a job sends to this service.
  TranslationChunkLimits get chunkLimits;

  /// Whether this service can translate into [language].
  bool supports(TranslationLanguage language);

  /// Translates [lines] into [target]; [song] is optional context that helps
  /// the service but is not translated. Throws
  /// [TranslationException] on failure.
  Future<TranslatedLines> translate(
    List<String> lines,
    TranslationLanguage target, {
    TranslationSongContext? song,
  });
}
