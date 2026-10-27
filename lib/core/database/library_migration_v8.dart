import 'package:drift/drift.dart';

import 'library_database.steps.dart';

/// Schema 7 to 8: `lyric_translations` and `lyric_translation_prefs`. Nothing
/// is backfilled; both tables start empty.
///
/// Runs in one transaction and can run again on a half-migrated file (drift
/// writes `user_version` after the step): drift creates each table with
/// `CREATE TABLE IF NOT EXISTS`.
Future<void> migrateLibraryToSchema8(
  GeneratedDatabase db,
  Migrator m,
  Schema8 schema,
) {
  return db.transaction(() async {
    for (final table in [
      schema.lyricTranslations,
      schema.lyricTranslationPrefs,
    ]) {
      await m.create(table);
    }
  });
}
