import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_database.steps.dart';
import 'package:kanaru/core/database/library_migration_v16.dart';

import 'generated/schema.dart';
import 'generated/schema_v15.dart' as v15;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  Future<void> seedV15(QueryExecutor connection) async {
    final old = v15.DatabaseAtV15(connection);
    await old.customStatement(
      'INSERT INTO lyric_translation_prefs (content_hash, target_lang, '
      "instruction) VALUES ('h1', 'vi', 'formal'), ('h2', NULL, 'x')",
    );
    await old.close();
  }

  Future<void> expectKept(GeneratedDatabase db) async {
    final rows = await db
        .customSelect(
          'SELECT content_hash, target_lang, instruction, service, tune_json, '
          'chosen_at FROM lyric_translation_prefs ORDER BY content_hash',
        )
        .get();
    expect(rows, hasLength(2));
    expect(rows[0].read<String>('target_lang'), 'vi');
    expect(rows[0].read<String>('instruction'), 'formal');
    expect(rows[1].read<String?>('target_lang'), isNull);
    for (final r in rows) {
      expect(r.read<String?>('service'), isNull);
      expect(r.read<String?>('tune_json'), isNull);
      expect(r.read<int?>('chosen_at'), isNull);
    }
  }

  test('adds the three NULL columns and keeps rows', () async {
    final schema = await verifier.schemaAt(15);
    await seedV15(schema.newConnection());
    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 16);
    await expectKept(db);
  });

  test('runs again on a migrated file', () async {
    final schema = await verifier.schemaAt(15);
    await seedV15(schema.newConnection());
    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 16);
    await migrateLibraryToSchema16(
      db,
      db.createMigrator(),
      Schema16(database: db),
    );
    await verifier.migrateAndValidate(db, 16);
    await expectKept(db);
  });

  test('runs on a half-migrated file that has one column', () async {
    final schema = await verifier.schemaAt(15);
    final old = v15.DatabaseAtV15(schema.newConnection());
    await old.customStatement(
      'INSERT INTO lyric_translation_prefs (content_hash, target_lang, '
      "instruction) VALUES ('h1', 'vi', 'formal'), ('h2', NULL, 'x')",
    );
    await old.customStatement(
      'ALTER TABLE lyric_translation_prefs ADD COLUMN service TEXT NULL',
    );
    await old.close();
    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 16);
    await expectKept(db);
  });
}
