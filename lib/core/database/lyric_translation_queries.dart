import 'package:drift/drift.dart';

import 'library_database.dart';
import 'lyrics_plugin_queries.dart';

/// Queries on the cached lyrics translations; see the invariants in
/// `lyric_translation_tables.dart`.
extension LyricTranslationQueries on LibraryDatabase {
  /// Every provider's row for one lyrics text and target language.
  Stream<List<LyricTranslationRow>> watchLyricTranslations(
    String hash,
    String targetLang,
  ) {
    return (select(lyricTranslations)..where(
          (t) => t.contentHash.equals(hash) & t.targetLang.equals(targetLang),
        ))
        .watch();
  }

  /// Inserts the row or replaces the row with the same
  /// (content_hash, provider, target_lang); other providers' rows stay.
  Future<void> saveLyricTranslation(LyricTranslationsCompanion row) =>
      into(lyricTranslations).insertOnConflictUpdate(row);

  /// The target language picked for this lyrics text, or null.
  Stream<String?> watchSongTranslationTarget(String hash) {
    return (select(lyricTranslationPrefs)
          ..where((t) => t.contentHash.equals(hash)))
        .watchSingleOrNull()
        .map((row) => row?.targetLang);
  }

  /// Sets the per-song target; null removes the choice. The row goes when
  /// it then holds neither a target nor an instruction.
  Future<void> setSongTranslationTarget(String hash, String? targetLang) =>
      _updatePref(
        hash,
        (row) => (target: targetLang, instruction: row?.instruction),
      );

  /// The instruction written for this lyrics text, or null.
  Stream<String?> watchSongTranslationInstruction(String hash) {
    return (select(lyricTranslationPrefs)
          ..where((t) => t.contentHash.equals(hash)))
        .watchSingleOrNull()
        .map((row) => row?.instruction);
  }

  Future<String?> songTranslationInstruction(String hash) async {
    final row = await (select(
      lyricTranslationPrefs,
    )..where((t) => t.contentHash.equals(hash))).getSingleOrNull();
    return row?.instruction;
  }

  /// Sets the per-song instruction; null or empty removes it. Same row rule
  /// as [setSongTranslationTarget].
  Future<void> setSongTranslationInstruction(String hash, String? text) =>
      _updatePref(
        hash,
        (row) => (
          target: row?.targetLang,
          instruction: (text == null || text.isEmpty) ? null : text,
        ),
      );

  /// Read-modify-write of one pref row in a transaction; the row is deleted
  /// when both values come out null.
  Future<void> _updatePref(
    String hash,
    ({String? target, String? instruction}) Function(
      LyricTranslationPrefRow? current,
    )
    change,
  ) {
    return transaction(() async {
      final current = await (select(
        lyricTranslationPrefs,
      )..where((t) => t.contentHash.equals(hash))).getSingleOrNull();
      final next = change(current);
      if (next.target == null && next.instruction == null) {
        await (delete(
          lyricTranslationPrefs,
        )..where((t) => t.contentHash.equals(hash))).go();
        return;
      }
      await into(lyricTranslationPrefs).insertOnConflictUpdate(
        LyricTranslationPrefsCompanion.insert(
          contentHash: hash,
          targetLang: Value(next.target),
          instruction: Value(next.instruction),
        ),
      );
    });
  }

  /// Row count and the UTF-8 size of all `lines_json` values.
  Stream<({int count, int bytes})> watchLyricTranslationStats() {
    return customSelect(
      'SELECT COUNT(*) AS n, '
      'COALESCE(SUM(LENGTH(CAST(lines_json AS BLOB))), 0) AS bytes '
      'FROM lyric_translations',
      readsFrom: {lyricTranslations},
    ).watchSingle().map(
      (r) => (count: r.read<int>('n'), bytes: r.read<int>('bytes')),
    );
  }

  /// Deletes every cached translation (not the per-song targets) and returns
  /// how many rows went. Then deletes the removed plugin records nothing
  /// names any more (saved lyrics, pins and rejects still count).
  Future<int> clearLyricTranslations() {
    return transaction(() async {
      final removed = await delete(lyricTranslations).go();
      await deleteUnreferencedRemovedPlugins();
      return removed;
    });
  }
}
