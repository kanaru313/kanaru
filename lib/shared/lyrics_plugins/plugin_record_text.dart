import '../../core/lyrics/plugins/lyrics_plugin_record.dart';
import '../../l10n/l10n.dart';

/// [bytes] as a short size in the user's language: bytes below 1 KB, then KB,
/// then MB.
String pluginSizeText(AppLocalizations l10n, int bytes) {
  if (bytes < 1024) return l10n.settingsUnitBytes(bytes);
  final kb = bytes / 1024;
  return kb < 1024
      ? l10n.settingsUnitKb(kb.round())
      : l10n.settingsUnitMb(kb / 1024);
}

/// The author as the plugin states it, flagged as self-declared (Kanaru does
/// not verify it), or a note that none was given.
String pluginAuthorText(AppLocalizations l10n, LyricsPluginRecord record) {
  final author = record.author?.trim() ?? '';
  return author.isEmpty
      ? l10n.lyricsSourceUnknownAuthor
      : l10n.lyricsSourceAuthor(author);
}

/// "author · v3": the line under a plugin's name.
String pluginByline(AppLocalizations l10n, LyricsPluginRecord record) =>
    '${pluginAuthorText(l10n, record)} · v${record.version}';
