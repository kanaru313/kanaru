import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/scan_stats_queries.dart';

import '../indexer/fake_tag_reader.dart';

void main() {
  late LibraryDatabase db;
  late int rootId;
  var next = 0;

  TracksCompanion row({String? cover, String? error}) {
    final n = next++;
    return TracksCompanion.insert(
      rootId: rootId,
      path: '/m/$n.mp3',
      mtimeMs: 1,
      sizeBytes: 1,
      title: 'T$n',
      addedAt: 1,
      updatedAt: 1,
      coverKey: Value(cover == null ? null : fakeCoverKey(cover)),
      scanError: Value(error),
    );
  }

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  test('an empty library counts zero', () async {
    expect(await db.scanDbStats(), (
      tracks: 0,
      tagErrors: 0,
      withCover: 0,
      covers: 0,
    ));
  });

  test('counts tag errors, tracks with a cover and distinct covers', () async {
    await db.upsertTracks([
      row(cover: 'one'),
      row(cover: 'one'),
      row(cover: 'two'),
      row(error: 'broken'),
      row(),
    ]);

    expect(await db.scanDbStats(), (
      tracks: 5,
      tagErrors: 1,
      withCover: 3,
      covers: 2,
    ));
  });
}
