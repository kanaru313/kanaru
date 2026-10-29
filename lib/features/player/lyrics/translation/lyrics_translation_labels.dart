import '../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/translation_language_name.dart';
import '../../../../shared/translation_notice_dialog.dart'
    show translationServiceName;

export '../../../../shared/translation_failure_message.dart';

/// The language information every state that has lyrics carries, or `null`
/// for [TranslationUnavailable].
TranslationTargetInfo? translationInfoOf(LyricsTranslationState state) =>
    switch (state) {
      TranslationUnavailable() => null,
      TranslationOff(:final info) => info,
      TranslationLoading(:final info) => info,
      TranslationReady(:final info) => info,
      TranslationSameLanguage(:final info) => info,
      TranslationFailed(:final info) => info,
      TranslationNeedsNotice(:final info) => info,
    };

/// Whether [state] is translation switched on and allowed to run.
bool translationIsActive(LyricsTranslationState state) => switch (state) {
  TranslationLoading() ||
  TranslationReady() ||
  TranslationSameLanguage() ||
  TranslationFailed() => true,
  TranslationUnavailable() ||
  TranslationOff() ||
  TranslationNeedsNotice() => false,
};

/// The tooltip of the header button for [state]: with translated lyrics the
/// credit, when the lyrics are already in the target language a note saying
/// so.
String translationButtonTooltip(
  AppLocalizations l10n,
  LyricsTranslationState state,
) => switch (state) {
  TranslationLoading() => l10n.lyricsTranslationButtonLoading,
  TranslationFailed() => l10n.lyricsTranslationButtonFailed,
  TranslationReady(:final service, :final info) =>
    l10n.lyricsTranslationAttribution(
      translationServiceName(service),
      translationLanguageName(l10n, info.effective),
    ),
  TranslationSameLanguage(:final info) => l10n.lyricsTranslationSameLanguage(
    languageNameInSentence(l10n, translationLanguageName(l10n, info.effective)),
  ),
  TranslationUnavailable() ||
  TranslationOff() ||
  TranslationNeedsNotice() => l10n.lyricsTranslationButton,
};

/// [name] for the middle of a sentence. Vietnamese language names start with
/// a capital ("Tiếng Việt") that reads wrong after "đã là"; English names
/// ("English") keep theirs.
String languageNameInSentence(AppLocalizations l10n, String name) =>
    l10n.localeName == 'vi' && name.isNotEmpty
    ? name[0].toLowerCase() + name.substring(1)
    : name;
