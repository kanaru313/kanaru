import '../../core/database/lyrics_plugin_spec.dart';
import '../../core/lyrics/plugins/lyrics_plugin_record.dart';
import '../../l10n/l10n.dart';

/// Where the plugin came from: its file name or its repository's name. It
/// tells apart plugins that share a name.
String pluginSourceText(AppLocalizations l10n, LyricsPluginRecord record) =>
    record.sourceKind == LyricsPluginSourceKind.repo
    ? l10n.lyricsSourceFromRepo(record.sourceName)
    : l10n.lyricsSourceFromFile(record.sourceName);
