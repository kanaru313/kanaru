import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_database.steps.dart';
import 'package:kanaru/core/database/library_migration_v8.dart';

import 'generated/schema.dart';
import 'generated/schema_v7.dart' as v7;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  Future<void> insertV7Data(GeneratedDatabase db) async {
    for (final sql in [
      "INSERT INTO library_roots (id, path, added_at) VALUES (1, '/m', 1)",
      'INSERT INTO tracks (id, root_id, path, mtime_ms, size_bytes, title, '
          'added_at, updated_at, title_sort) '
          "VALUES (1, 1, '/m/1.flac', 777, 1, 'Halo', 4242, 9, 'halo')",
      "INSERT INTO plays (path, played_at) VALUES ('/m/1.flac', 10)",
      "INSERT INTO playlists (id, name, created_at) VALUES (1, 'Mix', 5)",
      'INSERT INTO playlist_entries (playlist_id, path, position) '
          "VALUES (1, '/m/1.flac', 0)",
    ]) {
      await db.customStatement(sql);
    }
  }

  Future<int> count(GeneratedDatabase db, String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');

  Future<void> expectMigrated(GeneratedDatabase db) async {
    expect(await count(db, 'lyric_translations'), 0);
    expect(await count(db, 'lyric_translation_prefs'), 0);
    expect(await count(db, 'tracks'), 1);
    expect(await count(db, 'plays'), 1);
    expect(await count(db, 'playlists'), 1);
    expect(await count(db, 'playlist_entries'), 1);
  }

  test('adds both empty tables and keeps user data', () async {
    final schema = await verifier.schemaAt(7);
    final old = v7.DatabaseAtV7(schema.newConnection());
    await insertV7Data(old);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 8);
    await expectMigrated(db);
  });

  test('runs again on a half-migrated and on a migrated file', () async {
    final schema = await verifier.schemaAt(7);
    final old = v7.DatabaseAtV7(schema.newConnection());
    await insertV7Data(old);
    // A crashed earlier attempt: one table exists.
    await old.createMigrator().create(
      Schema8(database: old).lyricTranslationPrefs,
    );
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 8);
    await expectMigrated(db);

    await migrateLibraryToSchema8(
      db,
      db.createMigrator(),
      Schema8(database: db),
    );
    await verifier.migrateAndValidate(db, 8);
    await expectMigrated(db);
  });
}
