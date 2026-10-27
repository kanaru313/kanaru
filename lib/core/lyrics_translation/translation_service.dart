/// The online services that can translate lyrics. [name] (`google`, `deepl`)
/// is what the cache `provider` column and the settings store.
enum LyricsTranslationService {
  google,
  deepl;

  /// The other service, offered as the fallback when one fails.
  LyricsTranslationService get other => switch (this) {
    LyricsTranslationService.google => LyricsTranslationService.deepl,
    LyricsTranslationService.deepl => LyricsTranslationService.google,
  };
}
