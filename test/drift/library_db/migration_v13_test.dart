import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_database.steps.dart';
import 'package:kanaru/core/database/library_migration_v13.dart';

import 'generated/schema.dart';
import 'generated/schema_v12.dart' as v12;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  Future<void> insertV12Plugins(GeneratedDatabase db) async {
    for (final id in ['plugin-aaaaaaaaaaaa', 'plugin-bbbbbbbbbbbb']) {
      await db.customStatement(
        'INSERT INTO lyrics_plugins (install_id, name, version, api_version, '
        'hosts, config_schema, package_dir, source_kind, source_name, '
        "installed_at, updated_at) VALUES ('$id', 'P $id', 1, 1, '[]', '{}', "
        "'$id/v1-1', 'file', 'p.zip', 1, 1)",
      );
    }
  }

  Future<void> expectBothLyrics(GeneratedDatabase db) async {
    final rows = await db
        .customSelect('SELECT install_id, name, kind FROM lyrics_plugins')
        .get();
    expect(rows, hasLength(2));
    for (final row in rows) {
      expect(row.read<String>('kind'), 'lyrics');
      expect(row.read<String>('name'), 'P ${row.read<String>('install_id')}');
    }
  }

  test('existing plugin rows read as lyrics', () async {
    final schema = await verifier.schemaAt(12);
    final old = v12.DatabaseAtV12(schema.newConnection());
    await insertV12Plugins(old);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 13);
    await expectBothLyrics(db);
  });

  test('runs again on a migrated file', () async {
    final schema = await verifier.schemaAt(12);
    final old = v12.DatabaseAtV12(schema.newConnection());
    await insertV12Plugins(old);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 13);
    await migrateLibraryToSchema13(
      db,
      db.createMigrator(),
      Schema13(database: db),
    );
    await verifier.migrateAndValidate(db, 13);
    await expectBothLyrics(db);
  });

  test('runs on a half-migrated file that already has the column', () async {
    final schema = await verifier.schemaAt(12);
    final old = v12.DatabaseAtV12(schema.newConnection());
    await insertV12Plugins(old);
    await old.customStatement(
      "ALTER TABLE lyrics_plugins ADD COLUMN kind TEXT NOT NULL DEFAULT 'lyrics'",
    );
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 13);
    await expectBothLyrics(db);
  });
}
