import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_root_queries.dart';

import 'library_database_test.dart' show track;

TracksCompanion _t(int root, String path, String artist, String album) =>
    track(root, path, artist: artist).copyWith(album: Value(album));

void main() {
  late LibraryDatabase db;
  late int rootA, rootB;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    final ids = await db.addRoots(['/a', '/b'], now: 1);
    rootA = ids[0];
    rootB = ids[1];
    await db.upsertTracks([
      _t(rootA, '/a/1.flac', 'Ann; Bob', 'Alpha'),
      _t(rootA, '/a/2.flac', 'Ann', 'Alpha'),
      _t(rootB, '/b/1.flac', 'Cy', 'Beta'),
    ]);
  });
  tearDown(() => db.close());

  Future<int> artistLinks() async =>
      (await db.select(db.trackArtists).get()).length;

  test(
    'removeRoot deletes its tracks, artist links, albums and artists',
    () async {
      expect(await db.trackCountOfRoot(rootA), 2);

      await db.removeRoot(rootA);

      expect(await db.rootExists(rootA), isFalse);
      expect(await db.trackCountOfRoot(rootA), 0);
      expect(await db.trackCountOfRoot(rootB), 1);
      expect(await artistLinks(), 1, reason: 'only Cy remains');
      expect((await db.albums()).map((a) => a.title), ['Beta']);
      expect((await db.artistCredits()).map((a) => a.name), ['Cy']);
    },
  );

  test('removeRoot on an unknown id does nothing', () async {
    await db.removeRoot(999);
    expect((await db.roots()), hasLength(2));
  });

  test('replaceRoot swaps the root and drops the old tracks', () async {
    final id = await db.replaceRoot(rootA, '/c', now: 5);

    expect(id, isNot(rootA));
    expect((await db.roots()).map((r) => r.path), ['/b', '/c']);
    expect(await db.trackCountOfRoot(rootA), 0);
    expect(await db.trackCountOfRoot(id), 0);
    expect(await db.trackCountOfRoot(rootB), 1);
  });

  test('replaceRoot keeps the old root when the new path is taken', () async {
    await expectLater(db.replaceRoot(rootA, '/b', now: 5), throwsA(anything));

    expect((await db.roots()).map((r) => r.path), ['/a', '/b']);
    expect(await db.trackCountOfRoot(rootA), 2);
  });

  test('watchRoots emits again when a root goes', () async {
    final seen = <List<String>>[];
    final sub = db.watchRoots().listen(
      (roots) => seen.add([for (final r in roots) r.path]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await db.removeRoot(rootA);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();

    expect(seen.first, ['/a', '/b']);
    expect(seen.last, ['/b']);
  });
}
