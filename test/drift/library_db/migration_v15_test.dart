import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_database.steps.dart';
import 'package:kanaru/core/database/library_migration_v15.dart';

import 'generated/schema.dart';
import 'generated/schema_v14.dart' as v14;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  Future<void> seedV14(GeneratedDatabase db) async {
    await db.customStatement(
      'INSERT INTO lyrics_plugins (install_id, kind, name, version, '
      'api_version, hosts, config_schema, package_dir, source_kind, '
      "source_name, installed_at, updated_at) VALUES ('plugin-a', 'translate', "
      "'Tr', 1, 1, '[]', '{}', 'plugin-a/v1-1', 'file', 'a.zip', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO lyric_translations (content_hash, provider, target_lang, '
      "lines_json, created_at) VALUES ('h1', 'plugin-a', 'vi', '{\"a\":\"b\"}', 1)",
    );
    await db.customStatement(
      "INSERT INTO lyric_translation_prefs (content_hash, target_lang) "
      "VALUES ('h1', 'ja'), ('h2', 'vi')",
    );
  }

  Future<void> expectMigrated(GeneratedDatabase db) async {
    final plugin = await db
        .customSelect('SELECT name, translate_spec FROM lyrics_plugins')
        .getSingle();
    expect(plugin.read<String>('name'), 'Tr');
    expect(plugin.read<String?>('translate_spec'), isNull);
    final tr = await db
        .customSelect(
          'SELECT lines_json, settings_json FROM lyric_translations',
        )
        .getSingle();
    expect(tr.read<String>('lines_json'), '{"a":"b"}');
    expect(tr.read<String?>('settings_json'), isNull);
    final prefs = await db
        .customSelect(
          'SELECT content_hash, target_lang, instruction '
          'FROM lyric_translation_prefs ORDER BY content_hash',
        )
        .get();
    expect(prefs.map((r) => r.read<String>('content_hash')), ['h1', 'h2']);
    expect(prefs.map((r) => r.read<String?>('target_lang')), ['ja', 'vi']);
    expect(prefs.map((r) => r.read<String?>('instruction')), [null, null]);
    // target_lang accepts NULL now.
    await db.customStatement(
      "INSERT INTO lyric_translation_prefs (content_hash, instruction) "
      "VALUES ('h3', 'be formal')",
    );
  }

  test('v14 data is kept and the new columns are NULL', () async {
    final schema = await verifier.schemaAt(14);
    final old = v14.DatabaseAtV14(schema.newConnection());
    await seedV14(old);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 15);
    await expectMigrated(db);
  });

  test('runs again on a migrated file', () async {
    final schema = await verifier.schemaAt(14);
    final old = v14.DatabaseAtV14(schema.newConnection());
    await seedV14(old);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 15);
    await db.customStatement(
      "DELETE FROM lyric_translation_prefs WHERE content_hash = 'h3'",
    );
    await migrateLibraryToSchema15(
      db,
      db.createMigrator(),
      Schema15(database: db),
    );
    await verifier.migrateAndValidate(db, 15);
    await expectMigrated(db);
  });

  test('runs on a half-migrated file that already has the columns', () async {
    final schema = await verifier.schemaAt(14);
    final old = v14.DatabaseAtV14(schema.newConnection());
    await seedV14(old);
    await old.customStatement(
      'ALTER TABLE lyrics_plugins ADD COLUMN translate_spec TEXT NULL',
    );
    await old.customStatement(
      'ALTER TABLE lyric_translations ADD COLUMN settings_json TEXT NULL',
    );
    await old.customStatement(
      'ALTER TABLE lyric_translation_prefs ADD COLUMN instruction TEXT NULL',
    );
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 15);
    await expectMigrated(db);
  });
}
