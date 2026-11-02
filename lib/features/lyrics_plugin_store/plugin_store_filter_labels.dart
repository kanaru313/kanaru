import '../../core/database/lyrics_plugin_spec.dart' show PluginKind;
import '../../core/lyrics/plugins/package/plugin_languages.dart';
import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/language_display_name.dart';

/// The name of a plugin kind. The only per-kind UI code of the store: a new
/// [PluginKind] fails analysis here and nowhere else in the filter code.
String pluginKindLabel(AppLocalizations l10n, PluginKind kind) =>
    switch (kind) {
      PluginKind.lyrics => l10n.lyricsStoreKindLyrics,
      PluginKind.translate => l10n.lyricsStoreKindTranslate,
    };

/// The title of a filter group.
String storeFacetTitle(AppLocalizations l10n, StoreFacet facet) =>
    switch (facet) {
      StoreFacet.kind => l10n.lyricsStoreFilterGroupType,
      StoreFacet.language => l10n.lyricsStoreFilterGroupLanguage,
      StoreFacet.author => l10n.lyricsStoreFilterGroupAuthor,
      StoreFacet.source => l10n.lyricsStoreFilterGroupSource,
    };

/// What a value of [facet] is called on a chip.
String storeFacetValueLabel(
  AppLocalizations l10n,
  StoreFacet facet,
  StoreFacetValue value,
) {
  final key = value.key;
  switch (facet) {
    case StoreFacet.kind:
      final kind = PluginKind.fromValue(key);
      return kind == null ? key : pluginKindLabel(l10n, kind);
    case StoreFacet.language:
      return key == pluginLanguagesGlobal
          ? l10n.lyricsStoreLanguageGlobal
          : languageDisplayName(l10n, key);
    case StoreFacet.author:
      return value.label ?? key;
    case StoreFacet.source:
      return key == storeSourceFromFile
          ? l10n.lyricsStoreFromFile
          : value.label ?? Uri.tryParse(key)?.host ?? key;
  }
}
