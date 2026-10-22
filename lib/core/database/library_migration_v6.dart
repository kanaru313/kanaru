import 'package:drift/drift.dart';

import 'library_database.steps.dart';

/// Schema 5 to 6: `cover_colors`, `excluded_folders`, the nullable
/// `playlists.kind` column and the partial unique index that allows one
/// Favorites playlist. Nothing is backfilled: existing playlists keep a NULL
/// kind (ordinary playlists).
///
/// Runs in one transaction and can run again on a half-migrated file (drift
/// writes `user_version` after the step): tables are created if missing, the
/// column is added only when `playlists` lacks it and the index only when it
/// is missing.
Future<void> migrateLibraryToSchema6(
  GeneratedDatabase db,
  Migrator m,
  Schema6 schema,
) {
  return db.transaction(() async {
    for (final table in [schema.coverColors, schema.excludedFolders]) {
      await m.create(table);
    }
    final columns = await db.customSelect('PRAGMA table_info(playlists)').get();
    if (!columns.any((c) => c.read<String>('name') == 'kind')) {
      await m.addColumn(schema.playlists, schema.playlists.kind);
    }
    final index = schema.playlistsFavoritesUnique;
    final exists = await db
        .customSelect(
          'SELECT 1 FROM sqlite_master WHERE name = ?',
          variables: [Variable<String>(index.entityName)],
        )
        .get();
    if (exists.isEmpty) await m.create(index);
  });
}
