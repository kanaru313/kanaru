import 'package:drift/drift.dart';

import 'library_database.steps.dart';

/// Schema 6 to 7: the nullable `tracks.language` column and the
/// `tracks_language` and `tracks_added_at` indexes.
///
/// Every track gets `mtime_ms = -1`, a value no file has (a real mtime of 0
/// would otherwise never be re-read). That makes the next scan see each file as
/// changed and read its tags again, which is what fills `language`; `added_at`,
/// plays and playlists are untouched. Done only because the schema is not
/// released yet and the only databases at version 6 are development ones.
///
/// Runs in one transaction and can run again on a half-migrated file (drift
/// writes `user_version` after the step): the column is added only when
/// `tracks` lacks it and each index only when it is missing.
Future<void> migrateLibraryToSchema7(
  GeneratedDatabase db,
  Migrator m,
  Schema7 schema,
) {
  return db.transaction(() async {
    final columns = await db.customSelect('PRAGMA table_info(tracks)').get();
    if (!columns.any((c) => c.read<String>('name') == 'language')) {
      await m.addColumn(schema.tracks, schema.tracks.language);
    }
    for (final index in [schema.tracksLanguage, schema.tracksAddedAt]) {
      final exists = await db
          .customSelect(
            'SELECT 1 FROM sqlite_master WHERE name = ?',
            variables: [Variable<String>(index.entityName)],
          )
          .get();
      if (exists.isEmpty) await m.create(index);
    }
    // Forces the next scan to re-read tags so `language` gets filled.
    await db.customStatement('UPDATE tracks SET mtime_ms = -1');
  });
}
