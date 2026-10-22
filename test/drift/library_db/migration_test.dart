// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_keys_backfill.dart';
import 'package:kanaru/core/database/library_migration_v3.dart';
import 'package:kanaru/core/database/library_migration_v4.dart';
import 'package:kanaru/core/database/library_migration_v5.dart';
import 'package:kanaru/core/database/library_migration_v6.dart';
import 'package:kanaru/core/database/text_keys.dart';
import 'package:kanaru/core/database/library_database.steps.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;

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
      await db.customStatement(
        "INSERT INTO track_search(track_search, rank) "
        "VALUES ('integrity-check', 1)",
      );

      final rows = await (db.select(
        db.tracks,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      expect(rows.map((r) => r.keysVersion), everyElement(textKeysVersion));
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

  group('v3 to v4', () {
    final oldTracks = [
      const v3.TracksData(
        id: 1,
        rootId: 1,
        path: '/m/1.flac',
        mtimeMs: 1,
        sizeBytes: 1,
        title: 'Halo',
        artist: 'Beyoncé',
        album: 'I Am',
        genre: 'Pop',
        addedAt: 1,
        updatedAt: 1,
        coverScanVersion: 1,
        albumArtistKey: 'beyoncé',
        albumTitleKey: 'i am',
        albumDisplayArtist: 'Beyoncé',
        titleSort: 'halo',
        artistSort: 'beyonce',
        albumSort: 'i am',
        keysVersion: 1,
      ),
      const v3.TracksData(
        id: 2,
        rootId: 1,
        path: '/m/2.flac',
        mtimeMs: 1,
        sizeBytes: 1,
        title: 'Đừng Làm',
        artist: 'The Beatles',
        genre: 'Rock',
        addedAt: 1,
        updatedAt: 1,
        coverScanVersion: 1,
        titleSort: 'dung lam',
        artistSort: 'beatles',
        keysVersion: 1,
      ),
    ];

    Future<void> insertRoot(GeneratedDatabase db) => db.customStatement(
      "INSERT INTO library_roots (id, path, added_at) VALUES (1, '/m', 1)",
    );

    Future<List<int>> matching(GeneratedDatabase db, String fts) async => [
      for (final r
          in await db
              .customSelect(
                'SELECT rowid FROM track_search WHERE track_search MATCH ?1 '
                'ORDER BY rowid',
                variables: [Variable.withString(fts)],
              )
              .get())
        r.read<int>('rowid'),
    ];

    Future<void> expectIntact(GeneratedDatabase db) => db.customStatement(
      "INSERT INTO track_search(track_search, rank) "
      "VALUES ('integrity-check', 1)",
    );

    test(
      'keeps rows, adds empty search columns and indexes the stored titles',
      () async {
        await verifier.testWithDataIntegrity(
          oldVersion: 3,
          newVersion: 4,
          createOld: v3.DatabaseAtV3.new,
          createNew: v4.DatabaseAtV4.new,
          openTestedDatabase: LibraryDatabase.new,
          createItems: (batch, oldDb) {
            batch.insertAll(oldDb.libraryRoots, [
              const v3.LibraryRootsData(id: 1, path: '/m', addedAt: 1),
            ]);
            batch.insertAll(oldDb.tracks, oldTracks);
          },
          validateItems: (newDb) async {
            final rows = await (newDb.select(
              newDb.tracks,
            )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
            expect(rows.map((r) => r.title), ['Halo', 'Đừng Làm']);
            for (final row in rows) {
              expect(row.artistSearch, isNull);
              expect(row.albumSearch, isNull);
              expect(row.albumArtistSearch, isNull);
              expect(row.genreSearch, isNull);
              expect(row.keysVersion, 1);
            }
            // The rebuild ran: stored titles are findable right away.
            expect(await matching(newDb, 'halo'), [1]);
            expect(await matching(newDb, 'dun*'), [2]);
            await expectIntact(newDb);
          },
        );
      },
    );

    test('rows from v3 are searchable by artist and genre after the '
        'backfill', () async {
      final schema = await verifier.schemaAt(3);
      final old = v3.DatabaseAtV3(schema.newConnection());
      await insertRoot(old);
      await old.batch((b) => b.insertAll(old.tracks, oldTracks));
      await old.close();

      final db = LibraryDatabase(schema.newConnection());
      addTearDown(db.close);
      expect(await backfillLibraryKeys(db), 2);

      expect(await matching(db, 'artist_search:beyonce'), [1]);
      expect(await matching(db, 'artist_search:the'), [2]);
      expect(await matching(db, 'genre_search:rock'), [2]);
      expect(await matching(db, 'dung'), [2]);
      expect(await matching(db, 'genre_search:pop'), [1]);
      await expectIntact(db);
    });

    test('runs again on a half-migrated file and on a migrated one', () async {
      final schema = await verifier.schemaAt(3);
      final old = v3.DatabaseAtV3(schema.newConnection());
      await insertRoot(old);
      await old.batch((b) => b.insertAll(old.tracks, oldTracks));
      // A crashed earlier attempt: some columns and the index exist, the
      // triggers do not.
      await old.customStatement(
        'ALTER TABLE tracks ADD COLUMN artist_search TEXT NULL',
      );
      await old.customStatement(
        'ALTER TABLE tracks ADD COLUMN album_search TEXT NULL',
      );
      await old.customStatement(
        'CREATE VIRTUAL TABLE track_search USING fts5('
        'title_sort, artist_search, album_search, album_artist_search, '
        "genre_search, content='tracks', content_rowid='id', "
        "tokenize='unicode61 remove_diacritics 0', prefix='1 2 3')",
      );
      await old.close();

      final db = LibraryDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 4);
      expect(await matching(db, 'halo'), [1]);
      await expectIntact(db);

      // Once more on the finished schema.
      await migrateLibraryToSchema4(
        db,
        db.createMigrator(),
        Schema4(database: db),
      );
      await verifier.migrateAndValidate(db, 4);
      expect(await matching(db, 'halo'), [1]);
      await expectIntact(db);
    });
  });

  group('v4 to v5', () {
    const newTables = ['plays', 'play_stats', 'playlists', 'playlist_entries'];
    const triggers = [
      'plays_stats_insert',
      'plays_stats_delete',
      'plays_stats_update',
    ];

    Future<void> insertV4Library(v4.DatabaseAtV4 db) async {
      await db.customStatement(
        "INSERT INTO library_roots (id, path, added_at) VALUES (1, '/m', 1)",
      );
      await db.customStatement(
        'INSERT INTO tracks (id, root_id, path, mtime_ms, size_bytes, title, '
        'added_at, updated_at, title_sort) '
        "VALUES (1, 1, '/m/1.flac', 1, 1, 'Halo', 1, 1, 'halo')",
      );
      await db.customStatement(
        'INSERT INTO track_artists (track_id, artist_key, artist_name) '
        "VALUES (1, 'beyonce', 'Beyoncé')",
      );
    }

    Future<Set<String>> schemaNames(GeneratedDatabase db, String type) async =>
        {
          for (final r
              in await db
                  .customSelect(
                    'SELECT name FROM sqlite_master WHERE type = ?',
                    variables: [Variable.withString(type)],
                  )
                  .get())
            r.read<String>('name'),
        };

    Future<List<List<int>>> stats(GeneratedDatabase db, String path) async => [
      for (final r
          in await db
              .customSelect(
                'SELECT play_count, first_played_at, last_played_at '
                'FROM play_stats WHERE path = ?',
                variables: [Variable.withString(path)],
              )
              .get())
        [
          r.read<int>('play_count'),
          r.read<int>('first_played_at'),
          r.read<int>('last_played_at'),
        ],
    ];

    test('keeps rows and search, adds empty tables and the triggers', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 4,
        newVersion: 5,
        createOld: v4.DatabaseAtV4.new,
        createNew: v5.DatabaseAtV5.new,
        openTestedDatabase: LibraryDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.libraryRoots, [
            const v4.LibraryRootsData(id: 1, path: '/m', addedAt: 1),
          ]);
          batch.insertAll(oldDb.tracks, [
            const v4.TracksData(
              id: 1,
              rootId: 1,
              path: '/m/1.flac',
              mtimeMs: 1,
              sizeBytes: 1,
              title: 'Halo',
              addedAt: 1,
              updatedAt: 1,
              coverScanVersion: 0,
              titleSort: 'halo',
              keysVersion: 0,
            ),
          ]);
          batch.insertAll(oldDb.trackArtists, [
            const v4.TrackArtistsData(
              trackId: 1,
              artistKey: 'beyonce',
              artistName: 'Beyoncé',
            ),
          ]);
        },
        validateItems: (newDb) async {
          expect(
            (await newDb.select(newDb.libraryRoots).get()).map((r) => r.path),
            ["/m"],
          );
          expect((await newDb.select(newDb.tracks).get()).map((t) => t.path), [
            '/m/1.flac',
          ]);
          expect(await newDb.select(newDb.trackArtists).get(), hasLength(1));
          final hits = await newDb
              .customSelect(
                "SELECT rowid FROM track_search WHERE track_search MATCH 'halo'",
              )
              .get();
          expect(hits.map((r) => r.read<int>('rowid')), [1]);
          await newDb.customStatement(
            "INSERT INTO track_search(track_search, rank) "
            "VALUES ('integrity-check', 1)",
          );
          expect(await newDb.select(newDb.plays).get(), isEmpty);
          expect(await newDb.select(newDb.playStats).get(), isEmpty);
          expect(await newDb.select(newDb.playlists).get(), isEmpty);
          expect(await newDb.select(newDb.playlistEntries).get(), isEmpty);
          expect(await schemaNames(newDb, 'table'), containsAll(newTables));
          expect(await schemaNames(newDb, 'trigger'), containsAll(triggers));
        },
      );
    });

    test('triggers keep play_stats current on an upgraded file', () async {
      final schema = await verifier.schemaAt(4);
      final old = v4.DatabaseAtV4(schema.newConnection());
      await insertV4Library(old);
      await old.close();

      final db = LibraryDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 5);
      await db.customStatement(
        "INSERT INTO plays (path, played_at) VALUES ('/m/1.flac', 10)",
      );
      await db.customStatement(
        "INSERT INTO plays (path, played_at) VALUES ('/m/1.flac', 20)",
      );
      expect(await stats(db, '/m/1.flac'), [
        [2, 10, 20],
      ]);
      await db.customStatement('DELETE FROM plays');
      expect(await stats(db, '/m/1.flac'), isEmpty);
    });

    test('runs again on a half-migrated file and on a migrated one', () async {
      final schema = await verifier.schemaAt(4);
      final old = v4.DatabaseAtV4(schema.newConnection());
      await insertV4Library(old);
      // A crashed earlier attempt: the table, one index and an outdated
      // trigger exist; the version was never written.
      await old.customStatement(
        'CREATE TABLE plays (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        'path TEXT NOT NULL, played_at INTEGER NOT NULL, '
        'listened_ms INTEGER NULL)',
      );
      await old.customStatement(
        'CREATE INDEX plays_path_played ON plays (path, played_at)',
      );
      await old.customStatement(
        'CREATE TRIGGER plays_stats_insert AFTER INSERT ON plays '
        'BEGIN SELECT 1; END',
      );
      await old.close();

      final db = LibraryDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 5);

      // Once more on the finished schema.
      await migrateLibraryToSchema5(
        db,
        db.createMigrator(),
        Schema5(database: db),
      );
      await verifier.migrateAndValidate(db, 5);
      await db.customStatement(
        "INSERT INTO plays (path, played_at) VALUES ('/m/1.flac', 10)",
      );
      expect(await stats(db, '/m/1.flac'), [
        [1, 10, 10],
      ]);
    });
  });

  group('v5 to v6', () {
    Future<void> insertV5Data(GeneratedDatabase db) async {
      for (final sql in [
        "INSERT INTO library_roots (id, path, added_at) VALUES (1, '/m', 1)",
        'INSERT INTO tracks (id, root_id, path, mtime_ms, size_bytes, title, '
            'added_at, updated_at, title_sort, cover_key) '
            "VALUES (1, 1, '/m/1.flac', 1, 1, 'Halo', 1, 1, 'halo', 'ab/c')",
        "INSERT INTO plays (path, played_at) VALUES ('/m/1.flac', 10)",
        "INSERT INTO plays (path, played_at) VALUES ('/m/1.flac', 20)",
        "INSERT INTO playlists (id, name, created_at) VALUES (1, 'Mix', 5)",
        'INSERT INTO playlist_entries (playlist_id, path, position) '
            "VALUES (1, '/m/1.flac', 0), (1, '/m/gone.flac', 1)",
      ]) {
        await db.customStatement(sql);
      }
    }

    Future<int> count(GeneratedDatabase db, String table) async =>
        (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
            .read<int>('n');

    Future<void> expectV5DataKept(GeneratedDatabase db) async {
      expect(await count(db, 'library_roots'), 1);
      expect(await count(db, 'tracks'), 1);
      expect(await count(db, 'plays'), 2);
      expect(await count(db, 'playlist_entries'), 2);
      final stats = await db
          .customSelect('SELECT play_count FROM play_stats')
          .getSingle();
      expect(stats.read<int>('play_count'), 2);
      final playlist = await db
          .customSelect('SELECT name, kind FROM playlists')
          .getSingle();
      expect(playlist.read<String>('name'), 'Mix');
      expect(playlist.read<String?>('kind'), isNull);
      expect(await count(db, 'cover_colors'), 0);
      expect(await count(db, 'excluded_folders'), 0);
    }

    test('keeps user data, adds empty tables and a null kind', () async {
      final schema = await verifier.schemaAt(5);
      final old = v5.DatabaseAtV5(schema.newConnection());
      await insertV5Data(old);
      await old.close();

      final db = LibraryDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 6);
      await expectV5DataKept(db);

      // The play_stats triggers still run after the step.
      await db.customStatement(
        "INSERT INTO plays (path, played_at) VALUES ('/m/1.flac', 30)",
      );
      final stats = await db
          .customSelect('SELECT play_count, last_played_at FROM play_stats')
          .getSingle();
      expect(stats.read<int>('play_count'), 3);
      expect(stats.read<int>('last_played_at'), 30);

      // The partial unique index exists on the upgraded file.
      await db.customStatement(
        "INSERT INTO playlists (name, created_at, kind) "
        "VALUES ('Favorites', 6, 'favorites')",
      );
      await expectLater(
        db.customStatement(
          "INSERT INTO playlists (name, created_at, kind) "
          "VALUES ('Again', 7, 'favorites')",
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('runs again on a half-migrated file and on a migrated one', () async {
      final schema = await verifier.schemaAt(5);
      final old = v5.DatabaseAtV5(schema.newConnection());
      await insertV5Data(old);
      // A crashed earlier attempt: one new table exists; the column and the
      // index do not, and the version was never written.
      await old.customStatement(
        'CREATE TABLE cover_colors (cover_key TEXT NOT NULL, '
        'seed INTEGER NOT NULL, palette TEXT NOT NULL, '
        'algo_version INTEGER NOT NULL, PRIMARY KEY (cover_key))',
      );
      await old.close();

      final db = LibraryDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 6);
      await expectV5DataKept(db);

      // Once more on the finished schema.
      await migrateLibraryToSchema6(
        db,
        db.createMigrator(),
        Schema6(database: db),
      );
      await verifier.migrateAndValidate(db, 6);
      await expectV5DataKept(db);
    });

    test('runs on a file that already has the kind column', () async {
      final schema = await verifier.schemaAt(5);
      final old = v5.DatabaseAtV5(schema.newConnection());
      await insertV5Data(old);
      // A crashed earlier attempt added the column but not the index.
      await old.customStatement(
        'ALTER TABLE playlists ADD COLUMN kind TEXT NULL',
      );
      await old.close();

      final db = LibraryDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 6);
      await expectV5DataKept(db);
    });
  });
}
