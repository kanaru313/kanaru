import 'package:drift/drift.dart';

import 'library_database.steps.dart';

/// Schema 9 to 10: `lyrics_pins.mode` (the per-song lyrics choice) and
/// `online_lyrics_rejects.content_hash` (rejects match by text too).
///
/// A pin with a pick becomes `mode = 'online'`. A pin without a pick was the
/// old "show no online lyrics" skip, which no longer exists, so it is deleted
/// (the song goes back to automatic). Old rejects keep a null hash.
///
/// Runs in one transaction and can run again on a half-migrated file: each
/// column is added only when its table lacks it, and the data steps are
/// idempotent.
Future<void> migrateLibraryToSchema10(
  GeneratedDatabase db,
  Migrator m,
  Schema10 schema,
) {
  return db.transaction(() async {
    Future<bool> hasColumn(String table, String column) async {
      final columns = await db.customSelect('PRAGMA table_info($table)').get();
      return columns.any((c) => c.read<String>('name') == column);
    }

    if (!await hasColumn('lyrics_pins', 'mode')) {
      await m.addColumn(schema.lyricsPins, schema.lyricsPins.mode);
    }
    if (!await hasColumn('online_lyrics_rejects', 'content_hash')) {
      await m.addColumn(
        schema.onlineLyricsRejects,
        schema.onlineLyricsRejects.contentHash,
      );
    }
    await db.customStatement(
      "UPDATE lyrics_pins SET mode = 'online' "
      'WHERE mode IS NULL AND remote_id IS NOT NULL',
    );
    await db.customStatement(
      'DELETE FROM lyrics_pins WHERE mode IS NULL AND remote_id IS NULL',
    );
  });
}
