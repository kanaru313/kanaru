import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_database.steps.dart';
import 'package:kanaru/core/database/library_migration_v12.dart';

import 'generated/schema.dart';
import 'generated/schema_v11.dart' as v11;
import 'generated/schema_v12.dart' as v12;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  Future<void> insertV11Track(GeneratedDatabase db) async {
    for (final sql in [
      "INSERT INTO library_roots (id, path, added_at) VALUES (1, '/m', 1)",
      'INSERT INTO tracks (id, root_id, path, mtime_ms, size_bytes, title, '
          'artist, year, added_at, updated_at, cover_key, cover_scan_version) '
          "VALUES (1, 1, '/m/1.flac', 777, 5, 'Halo', 'Beyonce', 2008, 4242, "
          "9, 'ab/abc.jpg', 2)",
    ]) {
      await db.customStatement(sql);
    }
  }

  Future<void> expectKept(GeneratedDatabase db) async {
    final row = await db.customSelect('SELECT * FROM tracks').getSingle();
    expect(row.read<int>('id'), 1);
    expect(row.read<String>('path'), '/m/1.flac');
    expect(row.read<int>('mtime_ms'), 777);
    expect(row.read<String>('title'), 'Halo');
    expect(row.read<String>('artist'), 'Beyonce');
    expect(row.read<int>('year'), 2008);
    expect(row.read<int>('added_at'), 4242);
    expect(row.read<int>('updated_at'), 9);
    expect(row.read<String>('cover_key'), 'ab/abc.jpg');
    expect(row.read<int>('cover_scan_version'), 2);
    expect(row.data['extra_tags'], isNull);
  }

  test(
    'keeps every column of existing rows and adds a NULL extra_tags',
    () async {
      const oldTrack = v11.TracksData(
        id: 1,
        rootId: 1,
        path: '/m/1.flac',
        mtimeMs: 777,
        sizeBytes: 5,
        title: 'Halo',
        artist: 'Beyonce',
        year: 2008,
        addedAt: 4242,
        updatedAt: 9,
        coverKey: 'ab/abc.jpg',
        coverScanVersion: 2,
        titleSort: 'halo',
        keysVersion: 0,
      );
      await verifier.testWithDataIntegrity(
        oldVersion: 11,
        newVersion: 12,
        createOld: v11.DatabaseAtV11.new,
        createNew: v12.DatabaseAtV12.new,
        openTestedDatabase: LibraryDatabase.new,
        createItems: (batch, oldDb) {
          batch.insert(
            oldDb.libraryRoots,
            const v11.LibraryRootsData(id: 1, path: '/m', addedAt: 1),
          );
          batch.insert(oldDb.tracks, oldTrack);
        },
        validateItems: (newDb) async {
          final track = await newDb.select(newDb.tracks).getSingle();
          final json = track.toJson();
          expect(json.remove('extraTags'), isNull);
          expect(json, oldTrack.toJson());
        },
      );
      final schema = await verifier.schemaAt(11);
      final old = v11.DatabaseAtV11(schema.newConnection());
      await insertV11Track(old);
      await old.close();

      final db = LibraryDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 12);
      await expectKept(db);
    },
  );

  test('runs again on a migrated file', () async {
    final schema = await verifier.schemaAt(11);
    final old = v11.DatabaseAtV11(schema.newConnection());
    await insertV11Track(old);
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 12);
    await migrateLibraryToSchema12(
      db,
      db.createMigrator(),
      Schema12(database: db),
    );
    await verifier.migrateAndValidate(db, 12);
    await expectKept(db);
  });

  test('runs on a half-migrated file that already has the column', () async {
    final schema = await verifier.schemaAt(11);
    final old = v11.DatabaseAtV11(schema.newConnection());
    await insertV11Track(old);
    await old.customStatement('ALTER TABLE tracks ADD COLUMN extra_tags TEXT NULL');
    await old.close();

    final db = LibraryDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 12);
    await expectKept(db);
  });
}
