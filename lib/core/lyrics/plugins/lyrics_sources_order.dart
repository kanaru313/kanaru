import '../../database/library_database.dart';
import '../../database/lyrics_plugin_spec.dart';
import 'lyrics_plugin_record.dart';

/// One source the user can run: an installed lyrics plugin, held by [record].
class LyricsSourceEntry {
  const LyricsSourceEntry({
    required this.id,
    required this.enabled,
    required this.position,
    required this.record,
  });

  final String id;
  final bool enabled;

  /// Place in the user's order, lowest first.
  final int position;
  final LyricsPluginRecord record;
}

/// The sources that exist, in the user's order, from the plugin [records]
/// (removed ones and other kinds are not sources) and the saved [prefs].
///
/// A source with no preference row is on; a plugin without a row goes after
/// every saved position, in install order (the order of [records]). Ties are
/// broken by id.
List<LyricsSourceEntry> orderLyricsSources(
  List<LyricsPluginRecord> records,
  List<LyricsSourcePrefRow> prefs,
) {
  final byId = {for (final p in prefs) p.providerId: p};
  var next = prefs.fold(0, (top, p) => p.position > top ? p.position : top) + 1;
  final entries = [
    for (final record in records)
      if (!record.isRemoved && record.kind == PluginKind.lyrics)
        LyricsSourceEntry(
          id: record.installId,
          enabled: byId[record.installId]?.enabled ?? true,
          position: byId[record.installId]?.position ?? next++,
          record: record,
        ),
  ];
  return entries..sort((a, b) {
    final byPosition = a.position.compareTo(b.position);
    return byPosition != 0 ? byPosition : a.id.compareTo(b.id);
  });
}
