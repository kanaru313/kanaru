import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_database.steps.dart';
import 'package:kanaru/core/database/library_migration_v9.dart';

import 'generated/schema.dart';
import 'generated/schema_v8.dart' as v8;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  Future<void> insertV8Data(GeneratedDatabase db) async {
    for (final sql in [
      "INSERT INTO library_roots (id, path, added_at) VALUES (1, '/m', 1)",
      'INSERT INTO tracks (id, root_id, path, mtime_ms, size_bytes, title, '
          'added_at, updated_at, title_sort) '
          "VALUES (1, 1, '/m/1.flac', 777, 1, 'Halo', 4242, 9, 'halo')",
      "INSERT INTO plays (path, played_at) VALUES ('/m/1.flac', 10)",
      "INSERT INTO playlists (id, name, created_at) VALUES (1, 'Mix', 5)",
      'INSERT INTO playlist_entries (playlist_id, path, position) '
          "VALUES (1, '/m/1.flac', 0)",
      'INSERT INTO lyric_translations (content_hash, provider, target_lang, '
          "lines_json, created_at) VALUES ('h', 'google', 'vi', '{}', 3)",
    ]) {
      await db.customStatement(sql);
    }
  }

  Future<int> count(GeneratedDatabase db, String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');

  Future<void> expectMigrated(GeneratedDatabase db) async {
    expect(await count(db, 'online_lyrics'), 0);
    expect(await count(db, 'lyrics_pins'), 0);
    expect(await count(db, 'online_lyrics_rejects'), 0);
    expect(await count(db, 'tracks'), 1);
    expect(await count(db, 'plays'), 1);
    expect(await count(db, 'playlists'), 1);
    expect(await count(db, 'playlist_entries'), 1);
    expect(await count(db, 'lyric_translations'), 1);
  }

  test('adds the three empty tables and keeps user data', () async {
    final schema = await verifier.schemaAt(8);
    final old = v8.DatabaseAtV8(schema.newConnection());
    await insertV8Data(old);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 9);
    await expectMigrated(db);
  });

  test('runs again on a half-migrated and on a migrated file', () async {
    final schema = await verifier.schemaAt(8);
    final old = v8.DatabaseAtV8(schema.newConnection());
    await insertV8Data(old);
    // A crashed earlier attempt: one table exists.
    await old.createMigrator().create(Schema9(database: old).lyricsPins);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 9);
    await expectMigrated(db);

    await migrateLibraryToSchema9(
      db,
      db.createMigrator(),
      Schema9(database: db),
    );
    await verifier.migrateAndValidate(db, 9);
    await expectMigrated(db);
  });
}
