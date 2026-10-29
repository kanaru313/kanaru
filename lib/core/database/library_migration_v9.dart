import 'package:drift/drift.dart';

import 'library_database.steps.dart';

/// Schema 8 to 9: `online_lyrics`, `lyrics_pins` and `online_lyrics_rejects`.
/// Nothing is backfilled; all three tables start empty.
///
/// Runs in one transaction and can run again on a half-migrated file (drift
/// writes `user_version` after the step): drift creates each table with
/// `CREATE TABLE IF NOT EXISTS`.
Future<void> migrateLibraryToSchema9(
  GeneratedDatabase db,
  Migrator m,
  Schema9 schema,
) {
  return db.transaction(() async {
    for (final table in [
      schema.onlineLyrics,
      schema.lyricsPins,
      schema.onlineLyricsRejects,
    ]) {
      await m.create(table);
    }
  });
}
