import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_database.steps.dart';
import 'package:kanaru/core/database/library_migration_v10.dart';

import 'generated/schema.dart';
import 'generated/schema_v9.dart' as v9;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  Future<void> insertV9Data(GeneratedDatabase db) async {
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
      'INSERT INTO online_lyrics (cache_key, provider_id, status, remote_id, '
          "fetched_at) VALUES ('k', 'lrclib', 'found', 'r1', 1)",
      'INSERT INTO online_lyrics_rejects (cache_key, provider_id, remote_id, '
          "rejected_at) VALUES ('k', 'lrclib', 'bad', 2)",
    ]) {
      await db.customStatement(sql);
    }
  }

  /// A song with a pick and one with the old "no online lyrics" skip.
  Future<void> insertV9Pins(GeneratedDatabase db) async {
    await db.customStatement(
      'INSERT INTO lyrics_pins (track_key, provider_id, remote_id, '
      "plain_text, pinned_at) VALUES ('/m/pick', 'lrclib', 'r2', 'text', 7)",
    );
    await db.customStatement(
      "INSERT INTO lyrics_pins (track_key, pinned_at) VALUES ('/m/skip', 8)",
    );
  }

  Future<int> count(GeneratedDatabase db, String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');

  Future<void> expectMigrated(GeneratedDatabase db) async {
    expect(await count(db, 'tracks'), 1);
    expect(await count(db, 'plays'), 1);
    expect(await count(db, 'playlists'), 1);
    expect(await count(db, 'playlist_entries'), 1);
    expect(await count(db, 'lyric_translations'), 1);
    expect(await count(db, 'online_lyrics'), 1);

    final rejects = await db
        .customSelect(
          'SELECT remote_id, content_hash FROM online_lyrics_rejects',
        )
        .get();
    expect(rejects.single.read<String>('remote_id'), 'bad');
    expect(rejects.single.read<String?>('content_hash'), isNull);

    final pins = await db
        .customSelect(
          'SELECT track_key, mode, remote_id, pinned_at FROM lyrics_pins',
        )
        .get();
    // The pick gets mode online; the old skip row is gone.
    expect(pins, hasLength(1));
    expect(pins.single.read<String>('track_key'), '/m/pick');
    expect(pins.single.read<String?>('mode'), 'online');
    expect(pins.single.read<String?>('remote_id'), 'r2');
    expect(pins.single.read<int>('pinned_at'), 7);
  }

  test('adds both columns, marks picks online and drops skips', () async {
    final schema = await verifier.schemaAt(9);
    final old = v9.DatabaseAtV9(schema.newConnection());
    await insertV9Data(old);
    await insertV9Pins(old);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);
    await expectMigrated(db);
  });

  test('runs again when only mode exists and on a migrated file', () async {
    final schema = await verifier.schemaAt(9);
    final old = v9.DatabaseAtV9(schema.newConnection());
    await insertV9Data(old);
    await insertV9Pins(old);
    // A crashed earlier attempt: one column exists.
    final v10Pins = Schema10(database: old).lyricsPins;
    await old.createMigrator().addColumn(v10Pins, v10Pins.mode);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);
    await expectMigrated(db);

    await migrateLibraryToSchema10(
      db,
      db.createMigrator(),
      Schema10(database: db),
    );
    await verifier.migrateAndValidate(db, 10);
    await expectMigrated(db);
  });

  test('runs again when only content_hash exists', () async {
    final schema = await verifier.schemaAt(9);
    final old = v9.DatabaseAtV9(schema.newConnection());
    await insertV9Data(old);
    await insertV9Pins(old);
    // A crashed earlier attempt: the other column exists.
    final v10Rejects = Schema10(database: old).onlineLyricsRejects;
    await old.createMigrator().addColumn(v10Rejects, v10Rejects.contentHash);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);
    await expectMigrated(db);

    await migrateLibraryToSchema10(
      db,
      db.createMigrator(),
      Schema10(database: db),
    );
    await verifier.migrateAndValidate(db, 10);
    await expectMigrated(db);
  });
}
