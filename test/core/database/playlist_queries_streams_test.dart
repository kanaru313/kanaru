import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
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
      await db.addMissingToPlaylist(id, ['/m/a']);
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
      expect(before, 1);

      await db.upsertTracks([track(root, '/m/a'), track(root, '/m/b')]);
      await db.upsertTracks([
        track(root, '/m/a', title: 'Changed', mtimeMs: 2),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(emissions, before);
    });

    test('rename, move and remove each reach the watchers', () async {
      final id = await db.createPlaylist(
        'A',
        now: 1,
        paths: ['/m/a', '/m/b', '/m/c'],
      );
      final entries = (await db.playlistPage(id))!.entries;
      final names = <String>[];
      final nameSub = db.watchPlaylistSummaries().listen(
        (list) => names.add([for (final s in list) s.name].join()),
      );
      var entryUpdates = 0;
      final entrySub = db
          .tableUpdates(TableUpdateQuery.onTable(db.playlistEntries))
          .listen((_) => entryUpdates++);
      addTearDown(nameSub.cancel);
      addTearDown(entrySub.cancel);
      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 50));
      await settle();

      await db.renamePlaylist(id, 'B');
      await settle();
      expect(names, ['A', 'B']);

      await db.movePlaylistEntry(id, entries.first.entryId, 2);
      await settle();
      expect(entryUpdates, 1);

      await db.removePlaylistEntries(id, {entries.last.entryId});
      await settle();
      expect(entryUpdates, 2);
    });

    test('a remove that deletes nothing wakes nobody', () async {
      final id = await db.createPlaylist('A', now: 1, paths: ['/m/a']);
      var entryUpdates = 0;
      final sub = db
          .tableUpdates(TableUpdateQuery.onTable(db.playlistEntries))
          .listen((_) => entryUpdates++);
      addTearDown(sub.cancel);

      await db.removePlaylistEntries(id, {9999});
      await db.removePlaylistEntries(999, {1});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(entryUpdates, 0);
    });

    test('a move does not re-emit the summaries', () async {
      final id = await db.createPlaylist(
        'A',
        now: 1,
        paths: ['/m/a', '/m/b', '/m/c'],
      );
      final first = (await db.playlistPage(id))!.entries.first.entryId;
      var emissions = 0;
      final sub = db.watchPlaylistSummaries().listen((_) => emissions++);
      addTearDown(sub.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions, 1);

      await db.movePlaylistEntry(id, first, 2);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(emissions, 1);
    });
  });
}
