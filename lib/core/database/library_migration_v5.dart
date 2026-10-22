import 'package:drift/drift.dart';

import 'library_database.steps.dart';

/// Schema 4 to 5: listen history (`plays`, `play_stats`) and playlists
/// (`playlists`, `playlist_entries`), with their indexes and the triggers that
/// keep `play_stats` current. `plays` is created empty, so no backfill.
///
/// Runs in one transaction and can run again on a half-migrated file (drift
/// writes `user_version` after the step): tables are created if missing,
/// indexes only when missing and triggers are dropped and created again.
Future<void> migrateLibraryToSchema5(
  GeneratedDatabase db,
  Migrator m,
  Schema5 schema,
) {
  return db.transaction(() async {
    for (final table in [
      schema.plays,
      schema.playStats,
      schema.playlists,
      schema.playlistEntries,
    ]) {
      await m.create(table);
    }
    for (final index in [
      schema.playsPathPlayed,
      schema.playsPlayedAt,
      schema.playlistEntriesOrder,
    ]) {
      final exists = await db
          .customSelect(
            'SELECT 1 FROM sqlite_master WHERE name = ?',
            variables: [Variable<String>(index.entityName)],
          )
          .get();
      if (exists.isEmpty) await m.create(index);
    }
    for (final trigger in [
      schema.playsStatsInsert,
      schema.playsStatsDelete,
      schema.playsStatsUpdate,
    ]) {
      await db.customStatement('DROP TRIGGER IF EXISTS ${trigger.entityName}');
      await m.createTrigger(trigger);
    }
  });
}
