import 'package:drift/drift.dart';

import 'library_database.steps.dart';

/// Schema 2 to 3: the key columns, `track_artists` and their indexes. Schema
/// only, so it takes milliseconds at any library size; the keys themselves are
/// filled afterwards by `backfillLibraryKeys`.
///
/// Runs in one transaction and can run again on a half-migrated file: columns
/// are added only when missing and every statement uses `IF NOT EXISTS`.
Future<void> migrateLibraryToSchema3(
  GeneratedDatabase db,
  Migrator m,
  Schema3 schema,
) {
  final tracks = schema.tracks;
  return db.transaction(() async {
    final existing = {
      for (final row
          in await db.customSelect('PRAGMA table_info(tracks)').get())
        row.read<String>('name'),
    };
    for (final column in [
      tracks.albumArtistKey,
      tracks.albumTitleKey,
      tracks.albumDisplayArtist,
      tracks.titleSort,
      tracks.artistSort,
      tracks.albumSort,
      tracks.keysVersion,
    ]) {
      if (!existing.contains(column.$name)) await m.addColumn(tracks, column);
    }
    await m.createTable(schema.trackArtists);
    await db.customStatement('DROP INDEX IF EXISTS tracks_title');
    for (final index in [
      schema.tracksTitleSort,
      schema.tracksAlbumKey,
      schema.tracksKeysVersion,
      schema.trackArtistsTrack,
    ]) {
      await db.customStatement(
        index.createStatementsByDialect.values.first.replaceFirst(
          'CREATE INDEX ',
          'CREATE INDEX IF NOT EXISTS ',
        ),
      );
    }
  });
}
