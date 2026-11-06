import '../../../../core/lyrics_translation/translation_failure.dart';

/// Whether the failure is about the service key, which Retry cannot fix.
bool _isKeyError(TranslationFailureKind kind) =>
    kind == TranslationFailureKind.noKey ||
    kind == TranslationFailureKind.badKey;

/// Whether the plugin's settings page can fix the failure: its key is
/// missing, rejected, or cannot be read from a locked key store, or a
/// required setting is empty.
bool failureOpensPluginSettings(TranslationFailureKind kind) =>
    _isKeyError(kind) ||
    kind == TranslationFailureKind.keyStoreLocked ||
    kind == TranslationFailureKind.needsConfig;

/// Whether trying again may help. Too-long lyrics and an unsupported
/// language fail the same way every time.
bool failureCanRetry(TranslationFailureKind kind) =>
    !_isKeyError(kind) &&
    kind != TranslationFailureKind.needsConfig &&
    kind != TranslationFailureKind.tooLong &&
    kind != TranslationFailureKind.unsupportedLanguage;
