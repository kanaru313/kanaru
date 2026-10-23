import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_root_queries.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/core/database/queue_history_kind.dart';
import 'package:kanaru/core/database/queue_history_queries.dart';
import 'package:kanaru/core/database/queue_history_writes.dart';

import 'library_database_test.dart' show track;

List<String> _paths(int n, [String prefix = 'a']) => [
  for (var i = 0; i < n; i++) '/m/$prefix$i.flac',
];

void main() {
  late LibraryDatabase db;
  late int root;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    root = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  group('recordQueueSnapshot', () {
    test('a queue of fewer than two tracks is not saved', () async {
      expect(
        await db.recordQueueSnapshot(['/m/a.flac'], now: 1),
        QueueSnapshotOutcome.tooShort,
      );
      expect(
        await db.recordQueueSnapshot([], now: 1),
        QueueSnapshotOutcome.tooShort,
      );
      expect(await db.queueSnapshots(), isEmpty);
    });

    test('saves the paths in play order with dense positions', () async {
      final paths = ['/m/c.flac', '/m/a.flac', '/m/b.flac', '/m/a.flac'];
      expect(
        await db.recordQueueSnapshot(paths, now: 10),
        QueueSnapshotOutcome.saved,
      );
      final snapshot = (await db.queueSnapshots()).single;
      expect(snapshot.savedAt, 10);
      expect(snapshot.trackCount, 4);
      expect(await db.queueSnapshotPaths(snapshot.id), paths);
      final positions = await db
          .customSelect(
            'SELECT position FROM playlist_entries WHERE playlist_id = ?1 '
            'ORDER BY position',
            variables: [Variable.withInt(snapshot.id)],
          )
          .map((r) => r.read<int>('position'))
          .get();
      expect(positions, [0, 1, 2, 3]);
    });

    test('the same queue again only moves the time of the newest', () async {
      await db.recordQueueSnapshot(_paths(3), now: 10);
      expect(
        await db.recordQueueSnapshot(_paths(3), now: 20),
        QueueSnapshotOutcome.touched,
      );
      final snapshot = (await db.queueSnapshots()).single;
      expect(snapshot.savedAt, 20);
      expect(snapshot.trackCount, 3);
    });

    test('a queue equal to an older saved one is saved again', () async {
      await db.recordQueueSnapshot(_paths(3), now: 10);
      await db.recordQueueSnapshot(_paths(3, 'b'), now: 20);
      expect(
        await db.recordQueueSnapshot(_paths(3), now: 30),
        QueueSnapshotOutcome.saved,
      );
      expect((await db.queueSnapshots()).map((s) => s.savedAt), [30, 20, 10]);
    });

    test('a prefix, a longer queue or another order is a new queue', () async {
      await db.recordQueueSnapshot(_paths(3), now: 10);
      for (final (i, paths) in [
        _paths(2),
        _paths(4),
        _paths(3).reversed.toList(),
      ].indexed) {
        expect(
          await db.recordQueueSnapshot(paths, now: 20 + i),
          QueueSnapshotOutcome.saved,
          reason: '$paths',
        );
      }
    });

    test(
      'keeps the newest $queueSnapshotLimit, deleting entries too',
      () async {
        for (var i = 0; i < queueSnapshotLimit + 3; i++) {
          await db.recordQueueSnapshot(_paths(2, 'q$i-'), now: 100 + i);
        }
        final snapshots = await db.queueSnapshots();
        expect(snapshots, hasLength(queueSnapshotLimit));
        expect(snapshots.first.savedAt, 100 + queueSnapshotLimit + 2);
        expect(snapshots.last.savedAt, 103);
        final entries = await db
            .customSelect('SELECT COUNT(*) AS n FROM playlist_entries')
            .map((r) => r.read<int>('n'))
            .getSingle();
        expect(entries, queueSnapshotLimit * 2);
      },
    );

    test('never touches ordinary playlists or Favorites', () async {
      final playlist = await db.createPlaylist(
        'Mine',
        now: 1,
        paths: _paths(3),
      );
      await db.setFavorite('/m/a0.flac', favorite: true, now: 1);
      for (var i = 0; i < queueSnapshotLimit + 1; i++) {
        await db.recordQueueSnapshot(_paths(2, 'x$i'), now: 200 + i);
      }
      expect(await db.playlistSummary(playlist), isNotNull);
      expect(await db.isFavorite('/m/a0.flac'), isTrue);
      expect(await db.queueSnapshotPaths(playlist), isEmpty);
    });
  });

  group('reads', () {
    test('newest first, with the collage of library covers', () async {
      await db.upsertTracks([
        track(root, '/m/a0.flac').copyWith(coverKey: const Value('k0')),
        track(root, '/m/a1.flac').copyWith(coverKey: const Value('k1')),
      ]);
      await db.recordQueueSnapshot(_paths(2), now: 5);
      await db.recordQueueSnapshot(_paths(2, 'b'), now: 9);
      final snapshots = await db.queueSnapshots();
      expect(snapshots.map((s) => s.savedAt), [9, 5]);
      expect(snapshots.first.coverKeys, isEmpty);
      expect(snapshots.last.coverKeys, ['k0', 'k1']);
    });

    test('delete removes only a saved queue', () async {
      final mine = await db.createPlaylist('Mine', now: 1, paths: _paths(2));
      await db.recordQueueSnapshot(_paths(2), now: 5);
      final saved = (await db.queueSnapshots()).single.id;

      await db.deleteQueueSnapshot(mine);
      expect(await db.playlistSummary(mine), isNotNull);

      await db.deleteQueueSnapshot(saved);
      expect(await db.queueSnapshots(), isEmpty);
      expect(await db.playlistSummary(saved), isNull);
    });
  });
}
