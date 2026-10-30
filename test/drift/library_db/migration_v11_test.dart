import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_database.steps.dart';
import 'package:kanaru/core/database/library_migration_v11.dart';

import 'generated/schema.dart';
import 'generated/schema_v10.dart' as v10;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  Future<void> insertV10Data(GeneratedDatabase db) async {
    for (final sql in [
      "INSERT INTO library_roots (id, path, added_at) VALUES (1, '/m', 1)",
      'INSERT INTO tracks (id, root_id, path, mtime_ms, size_bytes, title, '
          'added_at, updated_at, title_sort) '
          "VALUES (1, 1, '/m/1.flac', 777, 1, 'Halo', 4242, 9, 'halo')",
      'INSERT INTO online_lyrics (cache_key, provider_id, status, remote_id, '
          "fetched_at) VALUES ('k', 'lrclib', 'found', 'r1', 1)",
      'INSERT INTO lyrics_pins (track_key, mode, remote_id, provider_id, '
          "pinned_at) VALUES ('/m/1.flac', 'online', 'r1', 'lrclib', 7)",
      'INSERT INTO online_lyrics_rejects (cache_key, provider_id, remote_id, '
          "rejected_at) VALUES ('k', 'lrclib', 'bad', 2)",
    ]) {
      await db.customStatement(sql);
    }
  }

  Future<int> count(GeneratedDatabase db, String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');

  Future<void> expectMigrated(GeneratedDatabase db) async {
    expect(await count(db, 'tracks'), 1);
    expect(await count(db, 'online_lyrics'), 1);
    expect(await count(db, 'lyrics_pins'), 1);
    expect(await count(db, 'online_lyrics_rejects'), 1);
    for (final table in [
      'lyrics_plugins',
      'lyrics_source_prefs',
      'lyrics_plugin_repos',
      'lyrics_plugin_data',
    ]) {
      expect(await count(db, table), 0, reason: table);
    }
    final index = await db
        .customSelect(
          "SELECT sql FROM sqlite_master "
          "WHERE name = 'lyrics_plugins_repo_unique'",
        )
        .getSingle();
    expect(index.read<String>('sql'), contains('WHERE repo_url IS NOT NULL'));
  }

  Future<void> rerunStep(LibraryDatabase db) =>
      migrateLibraryToSchema11(db, db.createMigrator(), Schema11(database: db));

  test('creates the four tables and the index', () async {
    final schema = await verifier.schemaAt(10);
    final old = v10.DatabaseAtV10(schema.newConnection());
    await insertV10Data(old);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 11);
    await expectMigrated(db);
  });

  test('the migrated index is unique only with a repo url', () async {
    final schema = await verifier.schemaAt(10);
    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 11);
    Future<void> insert(String id, String? url) => db.customStatement(
      'INSERT INTO lyrics_plugins (install_id, name, version, api_version, '
      'hosts, config_schema, package_dir, source_kind, source_name, '
      'repo_url, repo_slug, installed_at, updated_at) '
      "VALUES ('$id', 'n', 1, 1, '[]', '[]', 'd', 'file', 's', "
      "${url == null ? 'NULL' : "'$url'"}, 'slug', 1, 1)",
    );
    await insert('a', null);
    await insert('b', null);
    await insert('c', 'https://r');
    await expectLater(insert('d', 'https://r'), throwsA(isA<Exception>()));
  });

  test('runs again on a half-migrated file and on a migrated one', () async {
    final schema = await verifier.schemaAt(10);
    final old = v10.DatabaseAtV10(schema.newConnection());
    await insertV10Data(old);
    // A crashed earlier attempt: two tables exist, the rest do not.
    final v11 = Schema11(database: old);
    final m = old.createMigrator();
    await m.create(v11.lyricsPlugins);
    await m.create(v11.lyricsPluginRepos);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 11);
    await expectMigrated(db);

    await rerunStep(db);
    await verifier.migrateAndValidate(db, 11);
    await expectMigrated(db);
  });

  test('runs again when only the tables exist, without the index', () async {
    final schema = await verifier.schemaAt(10);
    final old = v10.DatabaseAtV10(schema.newConnection());
    await insertV10Data(old);
    final v11 = Schema11(database: old);
    final m = old.createMigrator();
    for (final table in [
      v11.lyricsPlugins,
      v11.lyricsSourcePrefs,
      v11.lyricsPluginRepos,
      v11.lyricsPluginData,
    ]) {
      await m.create(table);
    }
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 11);
    await expectMigrated(db);
  });
}
