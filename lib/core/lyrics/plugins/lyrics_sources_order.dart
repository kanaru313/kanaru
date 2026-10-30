import '../../database/library_database.dart';
import '../../database/lyrics_plugin_spec.dart';
import 'lyrics_plugin_record.dart';

/// One source the user can run: `lrclib` or an installed plugin. [record] is
/// set for a plugin and `null` for LRCLIB.
class LyricsSourceEntry {
  const LyricsSourceEntry({
    required this.id,
    required this.enabled,
    required this.position,
    this.record,
  });

  final String id;
  final bool enabled;

  /// Place in the user's order, lowest first.
  final int position;
  final LyricsPluginRecord? record;
}

/// The sources that exist, in the user's order, from the plugin [records]
/// (removed ones are not sources) and the saved [prefs].
///
/// A source with no preference row is on. `lrclib` without a row sits at
/// position 0; a plugin without a row goes after every saved position, in
/// install order (the order of [records]). Ties are broken by id.
List<LyricsSourceEntry> orderLyricsSources(
  List<LyricsPluginRecord> records,
  List<LyricsSourcePrefRow> prefs,
) {
  final byId = {for (final p in prefs) p.providerId: p};
  var next = prefs.fold(0, (top, p) => p.position > top ? p.position : top) + 1;
  LyricsSourceEntry entryOf(
    String id,
    LyricsPluginRecord? record,
    int Function() fallback,
  ) {
    final pref = byId[id];
    return LyricsSourceEntry(
      id: id,
      enabled: pref?.enabled ?? true,
      position: pref?.position ?? fallback(),
      record: record,
    );
  }

  final entries = [
    entryOf(lrclibSourceId, null, () => 0),
    for (final record in records)
      if (!record.isRemoved) entryOf(record.installId, record, () => next++),
  ];
  return entries..sort((a, b) {
    final byPosition = a.position.compareTo(b.position);
    return byPosition != 0 ? byPosition : a.id.compareTo(b.id);
  });
}
