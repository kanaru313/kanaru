import '../../core/database/lyrics_plugin_spec.dart';
import '../../core/lyrics/plugins/lyrics_plugin_record.dart';
import '../../l10n/l10n.dart';

/// The author as the plugin states it, flagged as self-declared (Kanaru does
/// not verify it), or a note that none was given.
String pluginAuthorText(AppLocalizations l10n, LyricsPluginRecord record) {
  final author = record.author?.trim() ?? '';
  return author.isEmpty
      ? l10n.lyricsSourceUnknownAuthor
      : l10n.lyricsSourceAuthor(author);
}

/// Where the plugin came from: its file name or its repository's name. It
/// tells apart plugins that share a name.
String pluginSourceText(AppLocalizations l10n, LyricsPluginRecord record) =>
    record.sourceKind == LyricsPluginSourceKind.repo
    ? l10n.lyricsSourceFromRepo(record.sourceName)
    : l10n.lyricsSourceFromFile(record.sourceName);

/// "author · v3": the line under a plugin's name.
String pluginByline(AppLocalizations l10n, LyricsPluginRecord record) =>
    '${pluginAuthorText(l10n, record)} · v${record.version}';
