import 'package:drift/drift.dart';

import 'library_database.steps.dart';

/// Schema 15 to 16: `lyric_translation_prefs.service` (TEXT NULL),
/// `tune_json` (TEXT NULL) and `chosen_at` (INTEGER NULL), the per-song
/// translation service choice.
///
/// Runs in one transaction and can run again on a half-migrated file: each
/// column is added only when `PRAGMA table_info` shows it missing.
Future<void> migrateLibraryToSchema16(
  GeneratedDatabase db,
  Migrator m,
  Schema16 schema,
) {
  return db.transaction(() async {
    final rows = await db
        .customSelect('PRAGMA table_info(lyric_translation_prefs)')
        .get();
    final names = {for (final r in rows) r.read<String>('name')};
    final prefs = schema.lyricTranslationPrefs;
    if (!names.contains('service')) await m.addColumn(prefs, prefs.service);
    if (!names.contains('tune_json')) await m.addColumn(prefs, prefs.tuneJson);
    if (!names.contains('chosen_at')) await m.addColumn(prefs, prefs.chosenAt);
  });
}
