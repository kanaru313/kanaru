import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/playlist_cover_keys.dart';
import 'package:kanaru/core/database/playlist_page_queries.dart';
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

  Future<void> addTracks(List<String> names, {Map<String, String>? covers}) =>
      db.upsertTracks([
        for (final n in names)
          track(
            root,
            '/m/$n',
            title: n.toUpperCase(),
          ).copyWith(coverKey: Value(covers?[n])),
      ]);

  Future<List<int>> entryIds(int id) async => [
    for (final e in await db.playlistEntriesAt(id, 0, 1000)) e.entry.entryId,
  ];

  group('head', () {
    test('is null for a playlist that does not exist', () async {
      expect(await db.playlistPageHead(99), isNull);
    });

    test('has the summary with its count, duplicates included', () async {
      await addTracks(['a']);
      final id = await db.createPlaylist(
        'Mix',
        now: 1,
        paths: ['/m/a', '/m/a', '/m/gone'],
      );

      final head = (await db.playlistPageHead(id))!;

      expect(head.playlist.name, 'Mix');
      expect(head.playlist.entryCount, 3);
    });

    test('has the collage of the first covered entries', () async {
      await addTracks(
        ['a', 'b', 'c', 'd', 'e'],
        covers: {'a': 'x', 'b': 'x', 'c': 'y', 'd': 'z', 'e': 'w'},
      );
      final id = await db.createPlaylist(
        'Mix',
        now: 1,
        paths: ['/m/gone', '/m/a', '/m/b', '/m/c', '/m/d', '/m/e'],
      );

      final head = (await db.playlistPageHead(id))!;

      expect(head.coverKeys, ['x', 'y', 'z', 'w']);
      expect(head.coverKeys, (await db.playlistPage(id))!.coverKeys);
    });

    test('looks for covers only in the first entries by position', () async {
      await addTracks(['near', 'far'], covers: {'near': 'x', 'far': 'y'});
      final gone = [
        for (var i = 0; i < playlistCollageEntryScanLimit; i++) '/m/gone$i',
      ];
      // The last entry looked at, and the first one not looked at.
      final within = await db.createPlaylist(
        'Within',
        now: 1,
        paths: [...gone.take(gone.length - 1), '/m/near', '/m/far'],
      );
      final beyond = await db.createPlaylist(
        'Beyond',
        now: 2,
        paths: [...gone, '/m/near'],
      );

      expect((await db.playlistPageHead(within))!.coverKeys, ['x']);
      expect((await db.playlistPageHead(beyond))!.coverKeys, isEmpty);
      // The grid reads the collage the same way.
      final cards = {
        for (final c in await db.playlistCards()) c.playlist.id: c.coverKeys,
      };
      expect(cards[within], ['x']);
      expect(cards[beyond], isEmpty);
    });

    test('can play when an entry has its file in the library', () async {
      await addTracks(['a']);
      final empty = await db.createPlaylist('Empty', now: 1);
      final allGone = await db.createPlaylist(
        'Gone',
        now: 2,
        paths: ['/m/x', '/m/y'],
      );
      final some = await db.createPlaylist(
        'Some',
        now: 3,
        paths: ['/m/x', '/m/a'],
      );

      expect((await db.playlistPageHead(empty))!.hasPlayable, isFalse);
      expect((await db.playlistPageHead(allGone))!.hasPlayable, isFalse);
      expect((await db.playlistPageHead(some))!.hasPlayable, isTrue);
    });
  });

  group('entries at', () {
    late int id;
    late List<String> names;

    setUp(() async {
      names = [for (var i = 0; i < 10; i++) 'n$i'];
      await addTracks(names.where((n) => n != 'n3').toList());
      id = await db.createPlaylist(
        'Mix',
        now: 1,
        paths: [for (final n in names) '/m/$n'],
      );
    });

    Future<List<String>> pathsAt(int start, int count) async => [
      for (final e in await db.playlistEntriesAt(id, start, count))
        e.entry.path.substring(3),
    ];

    test('returns the range in order, with positions', () async {
      final rows = await db.playlistEntriesAt(id, 2, 3);

      expect([for (final r in rows) r.position], [2, 3, 4]);
      expect([for (final r in rows) r.entry.path], ['/m/n2', '/m/n3', '/m/n4']);
      expect(rows[0].entry.track?.title, 'N2');
    });

    test('an entry without a library track has a null track', () async {
      final rows = await db.playlistEntriesAt(id, 3, 1);

      expect(rows.single.entry.track, isNull);
      expect(rows.single.entry.path, '/m/n3');
    });

    test('the last page is short and a start past the end is empty', () async {
      expect(await pathsAt(8, 5), ['n8', 'n9']);
      expect(await db.playlistEntriesAt(id, 10, 5), isEmpty);
      expect(await db.playlistEntriesAt(id, 500, 5), isEmpty);
      expect(await db.playlistEntriesAt(id, 0, 0), isEmpty);
    });

    test('follows a move and a removal', () async {
      final ids = await entryIds(id);

      await db.movePlaylistEntry(id, ids[0], 4);
      expect(await pathsAt(0, 6), ['n1', 'n2', 'n3', 'n4', 'n0', 'n5']);

      await db.removePlaylistEntries(id, {ids[2]});
      expect(await pathsAt(0, 6), ['n1', 'n3', 'n4', 'n0', 'n5', 'n6']);
      expect(await pathsAt(8, 5), ['n9']);
    });

    test('does not mix in another playlist', () async {
      await db.createPlaylist('Other', now: 2, paths: ['/m/n0', '/m/zz']);

      expect(await pathsAt(0, 100), names);
    });

    test('holes and duplicate positions do not crash', () async {
      await db.customStatement(
        'UPDATE playlist_entries SET position = 20 '
        'WHERE playlist_id = $id AND position = 4',
      );
      await db.customStatement(
        'UPDATE playlist_entries SET position = 5 '
        'WHERE playlist_id = $id AND position = 6',
      );

      final rows = await db.playlistEntriesAt(id, 0, 10);

      expect(
        [for (final r in rows) r.position],
        [
          0, 1, 2, 3, 5, 5, 7, 8, 9, //
        ],
      );
      expect(await db.playlistPlayableTracks(id), hasLength(9));
    });
  });

  group('playable tracks', () {
    test('skips entries outside the library, keeping order and ids', () async {
      await addTracks(['a', 'b', 'c']);
      final id = await db.createPlaylist(
        'Mix',
        now: 1,
        paths: ['/m/a', '/m/gone', '/m/b', '/m/c'],
      );
      final ids = await entryIds(id);

      var tracks = await db.playlistPlayableTracks(id);
      expect([for (final t in tracks) t.track.title], ['A', 'B', 'C']);
      expect([for (final t in tracks) t.entryId], [ids[0], ids[2], ids[3]]);
      expect([for (final t in tracks) t.position], [0, 2, 3]);

      await db.movePlaylistEntry(id, ids[3], 0);
      tracks = await db.playlistPlayableTracks(id);
      expect([for (final t in tracks) t.track.title], ['C', 'A', 'B']);
      expect([for (final t in tracks) t.position], [0, 1, 3]);
    });

    test('is empty for an empty or missing playlist', () async {
      final id = await db.createPlaylist('Empty', now: 1);

      expect(await db.playlistPlayableTracks(id), isEmpty);
      expect(await db.playlistPlayableTracks(99), isEmpty);
    });
  });
}
