import 'package:drift/drift.dart';

import 'library_database.dart';
import 'lyrics_plugin_spec.dart';

/// Queries on `lyrics_source_prefs`; see invariant 8 in
/// `lyrics_plugin_tables.dart`.
extension LyricsSourcePrefQueries on LibraryDatabase {
  Stream<List<LyricsSourcePrefRow>> watchLyricsSourcePrefs() =>
      (select(lyricsSourcePrefs)..orderBy([
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.providerId),
          ]))
          .watch();

  /// Whether [providerId] is on; false when it has no row or is off.
  Future<bool> lyricsSourceIsOn(String providerId) async {
    final row = await (select(
      lyricsSourcePrefs,
    )..where((t) => t.providerId.equals(providerId))).getSingleOrNull();
    return row?.enabled ?? false;
  }

  /// The position for a source with no row: after every row, 0 when none.
  Future<int> nextLyricsSourcePosition() async {
    final highest = lyricsSourcePrefs.position.max();
    final row = await (selectOnly(
      lyricsSourcePrefs,
    )..addColumns([highest])).getSingle();
    final max = row.read(highest);
    return max == null ? 0 : max + 1;
  }

  /// Whether a preference may be written for [providerId]: always for
  /// an id outside the plugin namespace, for a plugin only while its record
  /// exists, is not removed and is a lyrics plugin.
  Future<bool> _acceptsLyricsSourcePref(String providerId) async {
    if (!isLyricsPluginId(providerId)) return true;
    final row = await (select(
      lyricsPlugins,
    )..where((t) => t.installId.equals(providerId))).getSingleOrNull();
    return row != null &&
        row.removedAt == null &&
        row.kind == PluginKind.lyrics.value;
  }

  /// Turns a source on or off. A source with no row gets one at the end of
  /// the order; an existing row keeps its position. A plugin
  /// whose record is missing or removed is `skipped` and nothing is written,
  /// so a toggle from a stale list leaves no row behind.
  Future<LyricsPluginWrite> setLyricsSourceEnabled(
    String providerId,
    bool enabled,
  ) {
    return transaction(() async {
      if (!await _acceptsLyricsSourcePref(providerId)) {
        return LyricsPluginWrite.skipped;
      }
      final position = await nextLyricsSourcePosition();
      await into(lyricsSourcePrefs).insert(
        LyricsSourcePrefsCompanion.insert(
          providerId: providerId,
          enabled: Value(enabled),
          position: position,
        ),
        onConflict: DoUpdate(
          (_) => LyricsSourcePrefsCompanion(enabled: Value(enabled)),
        ),
      );
      return LyricsPluginWrite.written;
    });
  }

  /// Puts [ids] first, in the given order (a repeated id keeps its first
  /// place), then every other source after them in its current order, and
  /// rewrites all positions to 0..n in one transaction. Only plugin sources are
  /// ordered: a row whose id is outside the plugin namespace is left as it is.
  /// A source with no row gets one, enabled; `enabled` of existing rows is
  /// kept. Ids that are no plugin, or whose record is missing or removed, are
  /// left out and returned as `skipped`.
  Future<({List<String> written, List<String> skipped})> reorderLyricsSources(
    List<String> ids,
  ) {
    return transaction(() async {
      final written = <String>[];
      final skipped = <String>[];
      for (final id in ids.toSet()) {
        (isLyricsPluginId(id) && await _acceptsLyricsSourcePref(id)
                ? written
                : skipped)
            .add(id);
      }
      final current = [
        for (final row
            in await (select(lyricsSourcePrefs)..orderBy([
                  (t) => OrderingTerm.asc(t.position),
                  (t) => OrderingTerm.asc(t.providerId),
                ]))
                .get())
          if (isLyricsPluginId(row.providerId)) row.providerId,
      ];
      final order = [
        ...written,
        for (final id in current)
          if (!written.contains(id)) id,
      ];
      for (var i = 0; i < order.length; i++) {
        await into(lyricsSourcePrefs).insert(
          LyricsSourcePrefsCompanion.insert(providerId: order[i], position: i),
          onConflict: DoUpdate(
            (_) => LyricsSourcePrefsCompanion(position: Value(i)),
          ),
        );
      }
      return (written: written, skipped: skipped);
    });
  }
}
