import 'package:drift/drift.dart';

import 'library_database.steps.dart';

/// Schema 13 to 14: `playlists.description` (TEXT NOT NULL DEFAULT '', so
/// every existing playlist, Favorites and saved queue reads as empty).
///
/// Runs in one transaction and can run again on a half-migrated file (drift
/// writes `user_version` after the step): the column is added only when
/// `PRAGMA table_info(playlists)` lacks it.
Future<void> migrateLibraryToSchema14(
  GeneratedDatabase db,
  Migrator m,
  Schema14 schema,
) {
  return db.transaction(() async {
    final columns = {
      for (final row
          in await db.customSelect('PRAGMA table_info(playlists)').get())
        row.read<String>('name'),
    };
    if (!columns.contains('description')) {
      await m.addColumn(schema.playlists, schema.playlists.description);
    }
  });
}
