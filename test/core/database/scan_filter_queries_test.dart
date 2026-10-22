import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/scan_filter_queries.dart';

void main() {
  late LibraryDatabase db;
  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  TracksCompanion track(int rootId, String name, int? durationMs) =>
      TracksCompanion.insert(
        rootId: rootId,
        path: '/m$rootId/$name.mp3',
        mtimeMs: 1,
        sizeBytes: 1,
        title: name,
        addedAt: 1,
        updatedAt: 1,
        durationMs: Value(durationMs),
      );

  test('finds the tracks of one root shorter than the minimum', () async {
    final ids = await db.addRoots(['/m1', '/m2'], now: 1);
    await db.upsertTracks([
      track(ids[0], 'short', 5000),
      track(ids[0], 'edge', 10000),
      track(ids[0], 'long', 200000),
      track(ids[0], 'unknown', null),
      track(ids[1], 'other', 1000),
    ]);

    final found = await db.shortTrackIds(ids[0], 10000);

    final stored = await (db.select(
      db.tracks,
    )..where((t) => t.id.isIn(found))).get();
    expect(stored.map((t) => t.title), ['short']);
  });

  test('a minimum of 0 matches nothing', () async {
    final ids = await db.addRoots(['/m1'], now: 1);
    await db.upsertTracks([track(ids.single, 'short', 1)]);

    expect(await db.shortTrackIds(ids.single, 0), isEmpty);
  });
}
