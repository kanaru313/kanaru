import 'package:drift/drift.dart';

import 'library_database.steps.dart';

/// Schema 14 to 15:
/// - `lyrics_plugins.translate_spec` (TEXT NULL; the startup backfill fills
///   it for translation plugins installed before),
/// - `lyric_translations.settings_json` (TEXT NULL),
/// - `lyric_translation_prefs.instruction` (TEXT NULL) and `target_lang`
///   nullable. SQLite cannot drop NOT NULL in place, so the prefs table is
///   rebuilt with its rows copied.
///
/// Runs in one transaction and can run again on a half-migrated file (drift
/// writes `user_version` after the step): each change is made only when
/// `PRAGMA table_info` shows it missing.
Future<void> migrateLibraryToSchema15(
  GeneratedDatabase db,
  Migrator m,
  Schema15 schema,
) {
  return db.transaction(() async {
    final plugins = await _columns(db, 'lyrics_plugins');
    if (!plugins.containsKey('translate_spec')) {
      await m.addColumn(
        schema.lyricsPlugins,
        schema.lyricsPlugins.translateSpec,
      );
    }
    final translations = await _columns(db, 'lyric_translations');
    if (!translations.containsKey('settings_json')) {
      await m.addColumn(
        schema.lyricTranslations,
        schema.lyricTranslations.settingsJson,
      );
    }
    final prefs = await _columns(db, 'lyric_translation_prefs');
    if (prefs['target_lang'] == true || !prefs.containsKey('instruction')) {
      // Rebuild: new table with the new shape, rows copied, old one dropped.
      await m.alterTable(
        TableMigration(
          schema.lyricTranslationPrefs,
          newColumns: [
            if (!prefs.containsKey('instruction'))
              schema.lyricTranslationPrefs.instruction,
          ],
        ),
      );
    }
  });
}

/// Column name to "is NOT NULL" for [table].
Future<Map<String, bool>> _columns(GeneratedDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return {
    for (final row in rows)
      row.read<String>('name'): row.read<int>('notnull') == 1,
  };
}
