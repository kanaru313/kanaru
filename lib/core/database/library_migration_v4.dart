import 'package:drift/drift.dart';

import 'library_database.steps.dart';

/// Schema 3 to 4: the folded search columns, the `track_search` full-text
/// index and the triggers that keep it current. Schema plus one index
/// `rebuild`, no per-row Dart work, so it stays fast at any library size; the
/// search columns are filled afterwards by `backfillLibraryKeys`, and the
/// triggers re-index each row as it is keyed.
///
/// Runs in one transaction and can run again on a half-migrated file: columns
/// are added only when missing, the index is created only when missing and the
/// triggers are dropped and created again.
Future<void> migrateLibraryToSchema4(
  GeneratedDatabase db,
  Migrator m,
  Schema4 schema,
) {
  final tracks = schema.tracks;
  return db.transaction(() async {
    final existing = {
      for (final row
          in await db.customSelect('PRAGMA table_info(tracks)').get())
        row.read<String>('name'),
    };
    for (final column in [
      tracks.artistSearch,
      tracks.albumSearch,
      tracks.albumArtistSearch,
      tracks.genreSearch,
    ]) {
      if (!existing.contains(column.$name)) await m.addColumn(tracks, column);
    }
    final hasIndex = await db
        .customSelect("SELECT 1 FROM sqlite_master WHERE name = 'track_search'")
        .get();
    if (hasIndex.isEmpty) await m.create(schema.trackSearch);
    for (final trigger in [
      schema.tracksSearchInsert,
      schema.tracksSearchDelete,
      schema.tracksSearchUpdate,
    ]) {
      await db.customStatement('DROP TRIGGER IF EXISTS ${trigger.entityName}');
      await m.createTrigger(trigger);
    }
    // Rows from before this schema already have a `title_sort`; the index
    // must hold it before any trigger asks it to delete that value.
    await db.customStatement(
      "INSERT INTO track_search(track_search) VALUES ('rebuild')",
    );
  });
}
