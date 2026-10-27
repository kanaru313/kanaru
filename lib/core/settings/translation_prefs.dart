import '../lyrics_translation/translation_service.dart';

/// How a translated line is drawn next to the original.
enum LyricsTranslationDisplay {
  /// The translation under each original line.
  underLine,

  /// The translation instead of the original line.
  replace,
}

/// Options of the lyrics translation. Never holds a credential: the DeepL key
/// lives in the secret store.
class TranslationPrefs {
  const TranslationPrefs({
    this.show = false,
    this.service = LyricsTranslationService.google,
    this.targetLanguage,
    this.display = LyricsTranslationDisplay.underLine,
    this.noticeAcknowledged = const {},
  });

  /// Translated lines are shown (and fetched) for the playing song.
  final bool show;

  final LyricsTranslationService service;

  /// Language the lyrics are translated into, a code of
  /// `translationLanguages`; `null` follows the app's language.
  final String? targetLanguage;

  final LyricsTranslationDisplay display;

  /// Services the user accepted "lyrics will be sent to `<service>`" for.
  /// Switching to another service asks once more.
  final Set<LyricsTranslationService> noticeAcknowledged;

  /// The chosen [service] has not been accepted yet, so nothing may be sent.
  bool get needsNotice => !noticeAcknowledged.contains(service);

  TranslationPrefs copyWith({
    bool? show,
    LyricsTranslationService? service,
    LyricsTranslationDisplay? display,
    Set<LyricsTranslationService>? noticeAcknowledged,
  }) => TranslationPrefs(
    show: show ?? this.show,
    service: service ?? this.service,
    targetLanguage: targetLanguage,
    display: display ?? this.display,
    noticeAcknowledged: noticeAcknowledged ?? this.noticeAcknowledged,
  );

  /// Separate from [copyWith] because `null` is a valid target here.
  TranslationPrefs withTargetLanguage(String? targetLanguage) =>
      TranslationPrefs(
        show: show,
        service: service,
        targetLanguage: targetLanguage,
        display: display,
        noticeAcknowledged: noticeAcknowledged,
      );

  @override
  bool operator ==(Object other) =>
      other is TranslationPrefs &&
      other.show == show &&
      other.service == service &&
      other.targetLanguage == targetLanguage &&
      other.display == display &&
      other.noticeAcknowledged.length == noticeAcknowledged.length &&
      other.noticeAcknowledged.containsAll(noticeAcknowledged);

  @override
  int get hashCode => Object.hash(
    show,
    service,
    targetLanguage,
    display,
    Object.hashAllUnordered(noticeAcknowledged),
  );

  @override
  String toString() =>
      'TranslationPrefs(show: $show, service: ${service.name}, '
      'targetLanguage: $targetLanguage, display: ${display.name}, '
      'noticeAcknowledged: ${noticeAcknowledged.map((s) => s.name).toList()})';
}
