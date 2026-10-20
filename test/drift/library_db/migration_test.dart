// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

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
}
