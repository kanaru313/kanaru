import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_root_queries.dart';
import 'package:kanaru/core/database/playlist_queries.dart';

import 'library_database_test.dart' show track;

void main() {
  late LibraryDatabase db;
  late int root;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    root = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  group('reads', () {
    test('summaries are newest first, ties by higher id', () async {
      final old = await db.createPlaylist('Old', now: 1);
      final tieA = await db.createPlaylist('TieA', now: 5);
      final tieB = await db.createPlaylist('TieB', now: 5);

      final ids = [
        for (final s in await db.watchPlaylistSummaries().first) s.id,
      ];
      expect(ids, [tieB, tieA, old]);
    });

    test('summaries count entries, duplicates included', () async {
      final id = await db.createPlaylist(
        'A',
        now: 1,
        paths: ['/m/a', '/m/a', '/m/b'],
      );

      expect((await db.watchPlaylistSummaries().first).single.id, id);
      expect((await db.watchPlaylistSummaries().first).single.entryCount, 3);
    });

    test('a missing playlist has no summary and no page', () async {
      expect(await db.playlistSummary(99), isNull);
      expect(await db.playlistPage(99), isNull);
    });

    test(
      'an entry whose track is gone stays, and matches again by path',
      () async {
        await db.upsertTracks([track(root, '/m/a', title: 'A')]);
        final id = await db.createPlaylist(
          'A',
          now: 1,
          paths: ['/m/a', '/m/b'],
        );
        var entries = (await db.playlistPage(id))!.entries;
        expect(entries[0].track?.title, 'A');
        expect(entries[1].track, isNull);

        await db.removeRoot(root);
        entries = (await db.playlistPage(id))!.entries;
        expect([for (final e in entries) e.track], [null, null]);
        expect(entries.map((e) => e.path), ['/m/a', '/m/b']);

        final again = (await db.addRoots(['/m2'], now: 2)).single;
        await db.upsertTracks([track(again, '/m/a', title: 'A2')]);
        expect((await db.playlistPage(id))!.entries[0].track?.title, 'A2');
      },
    );

    test('collage keys are distinct, at most 4, nulls skipped', () async {
      TracksCompanion t(String path, String? cover) =>
          track(root, path).copyWith(coverKey: Value(cover));
      await db.upsertTracks([
        t('/m/1', null),
        t('/m/2', 'x'),
        t('/m/3', 'x'),
        t('/m/4', 'y'),
        t('/m/5', 'z'),
        t('/m/6', 'w'),
        t('/m/7', 'v'),
      ]);
      final id = await db.createPlaylist(
        'A',
        now: 1,
        paths: [for (var i = 1; i <= 7; i++) '/m/$i'],
      );
      final empty = await db.createPlaylist('Empty', now: 2);

      final cards = await db.playlistCards();
      expect(cards.map((c) => c.playlist.id), [empty, id]);
      expect(cards[0].coverKeys, isEmpty);
      expect(cards[1].coverKeys, ['x', 'y', 'z', 'w']);
      expect((await db.playlistPage(id))!.coverKeys, ['x', 'y', 'z', 'w']);
    });
  });

  group('streams', () {
    test('summaries re-emit on playlist writes', () async {
      final events = <List<String>>[];
      final sub = db.watchPlaylistSummaries().listen(
        (list) =>
            events.add([for (final s in list) '${s.name}:${s.entryCount}']),
      );
      addTearDown(sub.cancel);
      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 50));

      await settle();
      final id = await db.createPlaylist('A', now: 1);
      await settle();
      await db.addToPlaylist(id, ['/m/a']);
      await settle();
      await db.deletePlaylist(id);
      await settle();

      expect(events, [
        <String>[],
        ['A:0'],
        ['A:1'],
        <String>[],
      ]);
    });

    test('summaries stay silent when tracks change', () async {
      await db.createPlaylist('A', now: 1, paths: ['/m/a']);
      var emissions = 0;
      final sub = db.watchPlaylistSummaries().listen((_) => emissions++);
      addTearDown(sub.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final before = emissions;

      await db.upsertTracks([track(root, '/m/a'), track(root, '/m/b')]);
      await db.upsertTracks([
        track(root, '/m/a', title: 'Changed', mtimeMs: 2),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(emissions, before);
    });
  });
}
