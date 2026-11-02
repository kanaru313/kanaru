import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_database.steps.dart';
import 'package:kanaru/core/database/library_migration_v14.dart';

import 'generated/schema.dart';
import 'generated/schema_v13.dart' as v13;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  Future<void> insertV13Playlists(GeneratedDatabase db) async {
    await db.customStatement(
      'INSERT INTO playlists (id, name, created_at, kind) VALUES '
      "(1, 'Mix', 1, NULL), (2, 'Favorites', 1, 'favorites'), "
      "(3, 'Queue', 1, 'queue')",
    );
    await db.customStatement(
      'INSERT INTO playlist_entries (playlist_id, path, position) VALUES '
      "(1, '/a.mp3', 0), (1, '/b.mp3', 1)",
    );
  }

  Future<void> expectMigratedData(GeneratedDatabase db) async {
    final playlists = await db
        .customSelect('SELECT id, description FROM playlists ORDER BY id')
        .get();
    expect(playlists.map((r) => r.read<int>('id')), [1, 2, 3]);
    for (final row in playlists) {
      expect(row.read<String>('description'), '');
    }
    final entries = await db
        .customSelect('SELECT path FROM playlist_entries ORDER BY position')
        .get();
    expect(entries.map((r) => r.read<String>('path')), ['/a.mp3', '/b.mp3']);
    final description =
        (await db.customSelect('PRAGMA table_info(playlists)').get())
            .singleWhere((r) => r.read<String>('name') == 'description');
    expect(description.read<int>('notnull'), 1);
    expect(description.read<String>('dflt_value'), "''");
  }

  test('existing playlists get an empty description', () async {
    final schema = await verifier.schemaAt(13);
    final old = v13.DatabaseAtV13(schema.newConnection());
    await insertV13Playlists(old);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 14);
    await expectMigratedData(db);
    await db.customStatement(
      "INSERT INTO playlists (name, created_at) VALUES ('New', 2)",
    );
    final row = await db
        .customSelect("SELECT description FROM playlists WHERE name = 'New'")
        .getSingle();
    expect(row.read<String>('description'), '');
  });

  test('runs again on a migrated file', () async {
    final schema = await verifier.schemaAt(13);
    final old = v13.DatabaseAtV13(schema.newConnection());
    await insertV13Playlists(old);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 14);
    await migrateLibraryToSchema14(
      db,
      db.createMigrator(),
      Schema14(database: db),
    );
    await verifier.migrateAndValidate(db, 14);
    await expectMigratedData(db);
  });

  test('runs on a half-migrated file that already has the column', () async {
    final schema = await verifier.schemaAt(13);
    final old = v13.DatabaseAtV13(schema.newConnection());
    await insertV13Playlists(old);
    await old.customStatement(
      "ALTER TABLE playlists ADD COLUMN description TEXT NOT NULL DEFAULT ''",
    );
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 14);
    await expectMigratedData(db);
  });
}
