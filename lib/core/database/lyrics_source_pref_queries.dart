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

  /// The position for a source with no row: after every row, and never 0
  /// (the implicit position of `lrclib`).
  Future<int> nextLyricsSourcePosition() async {
    final highest = lyricsSourcePrefs.position.max();
    final row = await (selectOnly(
      lyricsSourcePrefs,
    )..addColumns([highest])).getSingle();
    final max = row.read(highest);
    return max == null ? 1 : max + 1;
  }

  /// Whether a preference may be written for [providerId]: always for
  /// `lrclib` (and any non-plugin id), for a plugin only while its record
  /// exists and is not removed.
  Future<bool> _acceptsLyricsSourcePref(String providerId) async {
    if (!isLyricsPluginId(providerId)) return true;
    final row = await (select(
      lyricsPlugins,
    )..where((t) => t.installId.equals(providerId))).getSingleOrNull();
    return row != null && row.removedAt == null;
  }

  /// Turns a source on or off. A source with no row gets one at the end of
  /// the order (`lrclib` at 0); an existing row keeps its position. A plugin
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
      final position = providerId == lrclibSourceId
          ? 0
          : await nextLyricsSourcePosition();
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
  /// rewrites all positions to 0..n in one transaction. `lrclib` with no row
  /// counts as the first current source, so when it is not in [ids] it gets a
  /// row after them instead of tying with the first id at 0. A source with
  /// no row gets one, enabled; `enabled` of existing rows is kept. Plugin ids
  /// whose record is missing or removed are left out and returned as
  /// `skipped`.
  Future<({List<String> written, List<String> skipped})> reorderLyricsSources(
    List<String> ids,
  ) {
    return transaction(() async {
      final written = <String>[];
      final skipped = <String>[];
      for (final id in ids.toSet()) {
        (await _acceptsLyricsSourcePref(id) ? written : skipped).add(id);
      }
      final current = [
        for (final row
            in await (select(lyricsSourcePrefs)..orderBy([
                  (t) => OrderingTerm.asc(t.position),
                  (t) => OrderingTerm.asc(t.providerId),
                ]))
                .get())
          row.providerId,
      ];
      if (!current.contains(lrclibSourceId)) current.insert(0, lrclibSourceId);
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
