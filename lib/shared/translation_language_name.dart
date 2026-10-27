import '../core/lyrics_translation/translation_language.dart';
import '../l10n/l10n.dart';
import 'language_display_name.dart';

/// What [lang] is called on screen. The two Chinese scripts have their own
/// names; every other language goes through [languageDisplayName].
String translationLanguageName(
  AppLocalizations l10n,
  TranslationLanguage lang,
) => switch (lang.nameKey) {
  'zh-Hans' => l10n.languageNameZhHans,
  'zh-Hant' => l10n.languageNameZhHant,
  final key => languageDisplayName(l10n, key),
};
