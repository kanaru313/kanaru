// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_keys_backfill.dart';
import 'package:kanaru/core/database/library_migration_v3.dart';
import 'package:kanaru/core/database/library_database.steps.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = LibraryDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test(
    'v1 to v2 keeps roots and tracks and adds empty cover columns',
    () async {
      final oldRoots = [
        const v1.LibraryRootsData(
          id: 1,
          path: '/music',
          addedAt: 10,
          lastScanAt: 20,
        ),
      ];
      final oldTracks = [
        const v1.TracksData(
          id: 7,
          rootId: 1,
          path: '/music/a.flac',
          mtimeMs: 100,
          sizeBytes: 2000,
          title: 'A',
          artist: 'Artist',
          album: 'Album',
          albumArtist: 'Album Artist',
          trackNo: 1,
          trackTotal: 9,
          discNo: 1,
          discTotal: 1,
          year: 2019,
          genre: 'Rock',
          composer: 'Composer',
          comment: 'Note',
          durationMs: 1000,
          bitrate: 900,
          sampleRate: 44100,
          bitDepth: 16,
          channels: 2,
          addedAt: 30,
          updatedAt: 40,
        ),
        const v1.TracksData(
          id: 9,
          rootId: 1,
          path: '/music/broken.dsf',
          mtimeMs: 200,
          sizeBytes: 10,
          title: 'broken',
          addedAt: 50,
          updatedAt: 60,
          scanError: 'unsupported',
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 1,
        newVersion: 2,
        createOld: v1.DatabaseAtV1.new,
        createNew: v2.DatabaseAtV2.new,
        openTestedDatabase: LibraryDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.libraryRoots, oldRoots);
          batch.insertAll(oldDb.tracks, oldTracks);
        },
        validateItems: (newDb) async {
          final roots = await newDb.select(newDb.libraryRoots).get();
          expect(roots.map((r) => r.toJson()), oldRoots.map((r) => r.toJson()));
          final tracks = await (newDb.select(
            newDb.tracks,
          )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
          expect(tracks, hasLength(2));
          for (final (i, track) in tracks.indexed) {
            final json = track.toJson();
            expect(json.remove('coverKey'), null);
            expect(json.remove('coverScanVersion'), 0);
            expect(json, oldTracks[i].toJson());
          }
        },
      );
    },
  );

  group('v2 to v3', () {
    // "Beyoncé" composed and decomposed, two artists in one tag, no album.
    const nfc = 'Beyoncé';
    const nfd = 'Beyoncé';
    final oldTracks = [
      const v2.TracksData(
        id: 1,
        rootId: 1,
        path: '/m/1.flac',
        mtimeMs: 1,
        sizeBytes: 1,
        title: 'Halo',
        artist: nfc,
        album: 'I Am',
        albumArtist: nfd,
        addedAt: 1,
        updatedAt: 1,
        coverScanVersion: 1,
      ),
      const v2.TracksData(
        id: 2,
        rootId: 1,
        path: '/m/2.flac',
        mtimeMs: 1,
        sizeBytes: 1,
        title: 'Đừng',
        artist: '$nfc; $nfd; Anh feat. Ánh',
        addedAt: 1,
        updatedAt: 1,
        coverScanVersion: 0,
      ),
    ];

    Future<void> insertRoot(v2.DatabaseAtV2 db) async {
      await db.customStatement(
        "INSERT INTO library_roots (id, path, added_at) VALUES (1, '/m', 1)",
      );
    }

    Future<Set<String>> names(GeneratedDatabase db, String sql) async => {
      for (final r in await db.customSelect(sql).get()) r.read<String>('name'),
    };

    test('keeps rows, adds empty key columns, swaps the title index', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 3,
        createOld: v2.DatabaseAtV2.new,
        createNew: v3.DatabaseAtV3.new,
        openTestedDatabase: LibraryDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.libraryRoots, [
            const v2.LibraryRootsData(id: 1, path: '/m', addedAt: 1),
          ]);
          batch.insertAll(oldDb.tracks, oldTracks);
        },
        validateItems: (newDb) async {
          final rows = await (newDb.select(
            newDb.tracks,
          )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
          expect(rows.map((r) => r.title), ['Halo', 'Đừng']);
          expect(rows.map((r) => r.artist), [nfc, '$nfc; $nfd; Anh feat. Ánh']);
          for (final row in rows) {
            expect(row.keysVersion, 0);
            expect(row.titleSort, '');
            expect(row.albumArtistKey, isNull);
          }
          expect(await newDb.select(newDb.trackArtists).get(), isEmpty);
          final indexes = await names(
            newDb,
            "SELECT name FROM sqlite_master WHERE type = 'index'",
          );
          expect(indexes, contains('tracks_title_sort'));
          expect(indexes, contains('tracks_album_key'));
          expect(indexes, contains('tracks_keys_version'));
          expect(indexes, contains('track_artists_track'));
          expect(indexes, isNot(contains('tracks_title')));
        },
      );
    });

    test('backfill after migration fills keys and track_artists', () async {
      final schema = await verifier.schemaAt(2);
      final old = v2.DatabaseAtV2(schema.newConnection());
      await insertRoot(old);
      await old.batch((b) => b.insertAll(old.tracks, oldTracks));
      await old.close();

      final db = LibraryDatabase(schema.newConnection());
      addTearDown(db.close);
      expect(await backfillLibraryKeys(db), 2);

      final rows = await (db.select(
        db.tracks,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      expect(rows.map((r) => r.keysVersion), everyElement(1));
      expect(rows[0].albumArtistKey, 'beyoncé');
      expect(rows[0].albumTitleKey, 'i am');
      expect(rows[0].titleSort, 'halo');
      expect(rows[1].titleSort, 'dung');
      expect(rows[1].albumTitleKey, isNull);
      final credits = await db
          .customSelect(
            'SELECT track_id, artist_key, artist_name FROM track_artists '
            'ORDER BY track_id, artist_key',
          )
          .get();
      expect(
        [
          for (final r in credits)
            (
              r.read<int>('track_id'),
              r.read<String>('artist_key'),
              r.read<String>('artist_name'),
            ),
        ],
        [
          (1, 'beyoncé', nfc),
          // NFC and NFD spellings are one artist; "Anh" and "Ánh" are two.
          (2, 'anh', 'Anh'),
          (2, 'beyoncé', nfc),
          (2, 'ánh', 'Ánh'),
        ],
      );
    });

    test('runs again on a half-migrated file and on a migrated one', () async {
      final schema = await verifier.schemaAt(2);
      final old = v2.DatabaseAtV2(schema.newConnection());
      await insertRoot(old);
      await old.batch((b) => b.insertAll(old.tracks, oldTracks));
      // A crashed earlier attempt: some columns and an index exist.
      await old.customStatement(
        "ALTER TABLE tracks ADD COLUMN title_sort TEXT NOT NULL DEFAULT ''",
      );
      await old.customStatement(
        'ALTER TABLE tracks ADD COLUMN keys_version INTEGER NOT NULL '
        'DEFAULT 0',
      );
      await old.customStatement(
        'CREATE INDEX tracks_title_sort ON tracks (title_sort, id)',
      );
      await old.close();

      final db = LibraryDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 3);
      expect(
        (await db.select(db.tracks).get()).map((r) => r.title),
        unorderedEquals(['Halo', 'Đừng']),
      );

      // Once more on the finished schema.
      await migrateLibraryToSchema3(
        db,
        db.createMigrator(),
        Schema3(database: db),
      );
      await verifier.migrateAndValidate(db, 3);
    });
  });
}
