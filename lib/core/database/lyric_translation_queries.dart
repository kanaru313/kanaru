import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show listEquals, immutable;

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
        .map((row) => row?.targetLang)
        .distinct();
  }

  /// Sets the per-song target; null removes the choice. The row goes when
  /// it then holds no target, instruction or service.
  Future<void> setSongTranslationTarget(String hash, String? targetLang) =>
      _updatePref(
        hash,
        (row) => (
          target: targetLang,
          instruction: row?.instruction,
          service: row?.service,
          tuneJson: row?.tuneJson,
          chosenAt: row?.chosenAt,
        ),
      );

  /// The instruction written for this lyrics text, or null.
  Stream<String?> watchSongTranslationInstruction(String hash) {
    return (select(lyricTranslationPrefs)
          ..where((t) => t.contentHash.equals(hash)))
        .watchSingleOrNull()
        .map((row) => row?.instruction)
        .distinct();
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
          service: row?.service,
          tuneJson: row?.tuneJson,
          chosenAt: row?.chosenAt,
        ),
      );

  /// Sets the per-song translation service (a plugin install id); null
  /// removes it together with its tune and time. A different service clears
  /// the tune; [chosenAt] (epoch ms) is stored with any service. A null
  /// [chosenAt] with a non-null service loses to the default when the newest
  /// choice wins ("Change every song") but still wins when songs set
  /// individually are kept, so callers always pass the clock value when they
  /// set a service.
  Future<void> setSongTranslationService(
    String hash,
    String? installId, {
    required int? chosenAt,
  }) => _updatePref(
    hash,
    (row) => (
      target: row?.targetLang,
      instruction: row?.instruction,
      service: installId,
      tuneJson: installId == row?.service ? row?.tuneJson : null,
      chosenAt: chosenAt,
    ),
  );

  /// Every song's own service choice (rows with a service), distinct by
  /// content.
  Stream<List<SongTranslationOverride>> watchSongTranslationOverrides() {
    return (select(lyricTranslationPrefs)
          ..where((t) => t.service.isNotNull())
          ..orderBy([(t) => OrderingTerm.asc(t.contentHash)]))
        .watch()
        .map(
          (rows) => [
            for (final r in rows)
              SongTranslationOverride(
                hash: r.contentHash,
                service: r.service!,
                tuneJson: r.tuneJson,
                chosenAt: r.chosenAt,
              ),
          ],
        )
        .distinct(listEquals);
  }

  /// Read-modify-write of one pref row in a transaction; the row is deleted
  /// when target, instruction and service all come out null. Without a
  /// service the tune and time are dropped.
  Future<void> _updatePref(
    String hash,
    ({
      String? target,
      String? instruction,
      String? service,
      String? tuneJson,
      int? chosenAt,
    })
    Function(LyricTranslationPrefRow? current)
    change,
  ) {
    return transaction(() async {
      final current = await (select(
        lyricTranslationPrefs,
      )..where((t) => t.contentHash.equals(hash))).getSingleOrNull();
      final next = change(current);
      if (next.target == null &&
          next.instruction == null &&
          next.service == null) {
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
          service: Value(next.service),
          tuneJson: Value(next.service == null ? null : next.tuneJson),
          chosenAt: Value(next.service == null ? null : next.chosenAt),
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

/// One song's own translation service choice (`lyric_translation_prefs` row
/// with a service); equal by content.
@immutable
class SongTranslationOverride {
  const SongTranslationOverride({
    required this.hash,
    required this.service,
    required this.tuneJson,
    required this.chosenAt,
  });

  final String hash;
  final String service;
  final String? tuneJson;
  final int? chosenAt;

  @override
  bool operator ==(Object other) =>
      other is SongTranslationOverride &&
      other.hash == hash &&
      other.service == service &&
      other.tuneJson == tuneJson &&
      other.chosenAt == chosenAt;

  @override
  int get hashCode => Object.hash(hash, service, tuneJson, chosenAt);
}
