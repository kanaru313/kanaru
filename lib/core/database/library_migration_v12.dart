import 'package:drift/drift.dart';

import 'library_database.steps.dart';

/// Schema 11 to 12: the nullable JSON column `tracks.extra_tags`. Existing
/// rows keep NULL; the next scan fills them (see `extraTagsVersion`).
///
/// Runs in one transaction and can run again on a half-migrated file (drift
/// writes `user_version` after the step): the column is added only when
/// `PRAGMA table_info(tracks)` lacks it.
Future<void> migrateLibraryToSchema12(
  GeneratedDatabase db,
  Migrator m,
  Schema12 schema,
) {
  return db.transaction(() async {
    final columns = {
      for (final row
          in await db.customSelect('PRAGMA table_info(tracks)').get())
        row.read<String>('name'),
    };
    if (!columns.contains('extra_tags')) {
      await m.addColumn(schema.tracks, schema.tracks.extraTags);
    }
  });
}
