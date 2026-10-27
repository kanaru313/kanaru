import 'translation_language.dart';
import 'translation_service.dart';

/// The result of translating a list of lines: [texts] and [detected] have the
/// same length as the input (implementations enforce this). [detected] holds
/// the source language reported per line, `null` when the service gave none.
class TranslatedLines {
  const TranslatedLines(this.texts, this.detected);

  final List<String> texts;
  final List<String?> detected;
}

/// One translation backend. A started job always runs to the end: there is no
/// cancellation, because a chunk is billed once sent and resending pays twice.
abstract interface class LyricsTranslator {
  LyricsTranslationService get service;

  /// Whether this service can translate into [language].
  bool supports(TranslationLanguage language);

  /// Translates [lines] into [target]; [context] is optional surrounding text
  /// that helps the service but is not translated. Throws
  /// [TranslationException] on failure.
  Future<TranslatedLines> translate(
    List<String> lines,
    TranslationLanguage target, {
    String? context,
  });
}
