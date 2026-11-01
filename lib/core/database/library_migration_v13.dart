import 'package:drift/drift.dart';

import 'library_database.steps.dart';

/// Schema 12 to 13: the text column `lyrics_plugins.kind` (`lyrics` or
/// `translate`). Existing rows get the SQL default `lyrics`.
///
/// Runs in one transaction and can run again on a half-migrated file (drift
/// writes `user_version` after the step): the column is added only when
/// `PRAGMA table_info(lyrics_plugins)` lacks it.
Future<void> migrateLibraryToSchema13(
  GeneratedDatabase db,
  Migrator m,
  Schema13 schema,
) {
  return db.transaction(() async {
    final columns = {
      for (final row
          in await db.customSelect('PRAGMA table_info(lyrics_plugins)').get())
        row.read<String>('name'),
    };
    if (!columns.contains('kind')) {
      await m.addColumn(schema.lyricsPlugins, schema.lyricsPlugins.kind);
    }
  });
}
