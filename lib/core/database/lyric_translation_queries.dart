import 'package:drift/drift.dart';

import 'library_database.dart';

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

  /// Sets the per-song target; null removes the choice.
  Future<void> setSongTranslationTarget(String hash, String? targetLang) async {
    if (targetLang == null) {
      await (delete(
        lyricTranslationPrefs,
      )..where((t) => t.contentHash.equals(hash))).go();
      return;
    }
    await into(lyricTranslationPrefs).insertOnConflictUpdate(
      LyricTranslationPrefsCompanion.insert(
        contentHash: hash,
        targetLang: targetLang,
      ),
    );
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
  /// how many rows went.
  Future<int> clearLyricTranslations() => delete(lyricTranslations).go();
}
