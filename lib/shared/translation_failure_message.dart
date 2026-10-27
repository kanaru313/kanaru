import '../core/lyrics_translation/translation_failure.dart';
import '../l10n/l10n.dart';

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
