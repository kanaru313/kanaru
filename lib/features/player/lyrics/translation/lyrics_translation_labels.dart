import '../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../core/lyrics_translation/translation_failure.dart';
import '../../../../l10n/l10n.dart';

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

/// The sentence that tells the user why a translation failed.
String translationFailureMessage(
  AppLocalizations l10n,
  TranslationFailureKind kind,
) => switch (kind) {
  TranslationFailureKind.network => l10n.lyricsTranslationFailNetwork,
  TranslationFailureKind.noKey => l10n.lyricsTranslationFailNoKey,
  TranslationFailureKind.badKey => l10n.lyricsTranslationFailBadKey,
  TranslationFailureKind.quotaExceeded => l10n.lyricsTranslationFailQuota,
  TranslationFailureKind.rateLimited => l10n.lyricsTranslationFailRateLimited,
  TranslationFailureKind.blocked => l10n.lyricsTranslationFailBlocked,
  TranslationFailureKind.unsupportedLanguage =>
    l10n.lyricsTranslationFailUnsupportedLanguage,
  TranslationFailureKind.tooLong => l10n.lyricsTranslationFailTooLong,
  TranslationFailureKind.server => l10n.lyricsTranslationFailServer,
  TranslationFailureKind.invalidResponse =>
    l10n.lyricsTranslationFailInvalidResponse,
  TranslationFailureKind.emptyResult => l10n.lyricsTranslationFailEmptyResult,
  TranslationFailureKind.keyStoreLocked =>
    l10n.lyricsTranslationFailKeyStoreLocked,
  TranslationFailureKind.keyStoreUnavailable =>
    l10n.lyricsTranslationFailKeyStoreUnavailable,
};

/// The tooltip of the header button for [state].
String translationButtonTooltip(
  AppLocalizations l10n,
  LyricsTranslationState state,
) => switch (state) {
  TranslationLoading() => l10n.lyricsTranslationButtonLoading,
  TranslationFailed() => l10n.lyricsTranslationButtonFailed,
  TranslationReady() ||
  TranslationSameLanguage() => l10n.lyricsTranslationButtonOn,
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
