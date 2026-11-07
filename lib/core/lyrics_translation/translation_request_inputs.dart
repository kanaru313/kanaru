import '../lyrics/plugins/lyrics_plugin_record.dart';
import '../settings/translation_prefs.dart';
import 'translation_language.dart';
import 'translation_service.dart';

/// The language translated into when a song has no language of its own: the
/// user's pick, else the app language, else English. Shared by the screen and
/// the queue prefetch so both ask for the same row.
TranslationLanguage defaultTranslationTarget(
  TranslationPrefs prefs,
  String appLang,
) =>
    translationLanguageFor(prefs.targetLanguage ?? appLang) ??
    translationLanguageFor('en')!;

/// The language for one song: its own code when it is a known language, else
/// [defaultTarget].
TranslationLanguage effectiveTranslationTarget(
  TranslationLanguage defaultTarget,
  String? songOverride,
) =>
    (songOverride == null ? null : translationLanguageFor(songOverride)) ??
    defaultTarget;

/// The translation services among the plugin [records]: every one ever
/// installed (`known`, so a removed plugin's saved row is still recognised)
/// and those still installed (`live`).
({Set<TranslationServiceId> known, Set<TranslationServiceId> live})
translationPluginSets(Iterable<LyricsPluginRecord> records) => (
  known: {
    for (final r in records)
      if (r.kind?.isTranslation == true)
        ?TranslationServiceId.tryParse(r.installId),
  },
  live: {
    for (final r in records)
      if (r.kind?.isTranslation == true && !r.isRemoved)
        ?TranslationServiceId.tryParse(r.installId),
  },
);
