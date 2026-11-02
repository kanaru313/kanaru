import 'package:drift/drift.dart'
    show OrderingTerm, TableUpdate, TableUpdateQuery, Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/database/playlist_queries.dart';

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<(String, int)>> entries(int id) async {
    final page = await db.playlistPage(id);
    final rows =
        await (db.select(db.playlistEntries)
              ..where((e) => e.playlistId.equals(id))
              ..orderBy([(e) => OrderingTerm.asc(e.position)]))
            .get();
    expect(page, isNotNull);
    return [for (final r in rows) (r.path, r.position)];
  }

  group('updatePlaylistDetails', () {
    test('trims and strips control characters', () async {
      final id = await db.createPlaylist('A', now: 1);
      await db.updatePlaylistDetails(
        id,
        name: '  Na\u0000me\n ',
        description: ' line1\nline2\t\u0001x ',
      );
      final p = (await db.playlistSummary(id))!;
      expect(p.name, 'Name');
      expect(p.description, 'line1\nline2\tx');
    });

    test('blank name throws', () async {
      final id = await db.createPlaylist('A', now: 1);
      expect(
        () => db.updatePlaylistDetails(id, name: ' \u0000 ', description: ''),
        throwsArgumentError,
      );
    });

    test('limits count graphemes', () async {
      final id = await db.createPlaylist('A', now: 1);
      expect(
        () => db.updatePlaylistDetails(id, name: 'a' * 201, description: ''),
        throwsArgumentError,
      );
      expect(
        () => db.updatePlaylistDetails(id, name: 'a', description: 'b' * 2001),
        throwsArgumentError,
      );
      // 200 emoji are 400 UTF-16 units; decomposed e + accent is 1 grapheme.
      await db.updatePlaylistDetails(
        id,
        name: '\u{1F600}' * 200,
        description: 'é' * 2000,
      );
      expect((await db.playlistSummary(id))!.name.runes.length, 200);
    });

    test('Favorites and gone ids are untouched', () async {
      final fav = await db.ensureFavoritesPlaylist(now: 1);
      final before = (await db.playlistSummary(fav))!;
      await db.updatePlaylistDetails(fav, name: 'X', description: 'Y');
      await db.updatePlaylistDetails(999, name: 'X', description: 'Y');
      expect(await db.playlistSummary(fav), before);
      expect(await db.playlistSummary(999), isNull);
    });

    test('a saved queue is untouched', () async {
      final q = await db
          .into(db.playlists)
          .insert(
            PlaylistsCompanion.insert(
              name: 'Q',
              createdAt: 1,
              kind: const Value(queueKind),
            ),
          );
      await db.updatePlaylistDetails(q, name: 'X', description: 'Y');
      final p = (await db.playlistSummary(q))!;
      expect((p.name, p.description), ('Q', ''));
    });

    test('2000 emoji description passes, 2001 throws', () async {
      final id = await db.createPlaylist('A', now: 1);
      await db.updatePlaylistDetails(
        id,
        name: 'A',
        description: '\u{1F600}' * 2000,
      );
      expect(
        () => db.updatePlaylistDetails(
          id,
          name: 'A',
          description: '\u{1F600}' * 2001,
        ),
        throwsArgumentError,
      );
    });

    test('equal values write nothing', () async {
      final id = await db.createPlaylist('A', now: 1);
      await db.updatePlaylistDetails(id, name: 'A', description: 'd');
      final events = <Set<TableUpdate>>[];
      final sub = db
          .tableUpdates(TableUpdateQuery.onTable(db.playlists))
          .listen(events.add);
      await db.updatePlaylistDetails(id, name: ' A ', description: 'd');
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      await db.updatePlaylistDetails(id, name: 'A', description: 'e');
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      await sub.cancel();
    });
  });

  group('duplicatePlaylist', () {
    test('copies entries, description, as an ordinary playlist', () async {
      final id = await db.createPlaylist(
        'A',
        now: 1,
        paths: ['/a', '/b', '/a'],
      );
      await db.updatePlaylistDetails(id, name: 'A', description: 'desc');
      final copy = await db.duplicatePlaylist(id, name: 'A (copy)', now: 5);
      expect(copy, isNotNull);
      expect(await entries(copy!), [('/a', 0), ('/b', 1), ('/a', 2)]);
      final p = (await db.playlistSummary(copy))!;
      expect(p.name, 'A (copy)');
      expect(p.description, 'desc');
      expect(p.createdAt, 5);
      expect(p.isFavorites, isFalse);
    });

    test('from Favorites gives an ordinary playlist', () async {
      final fav = await db.ensureFavoritesPlaylist(now: 1);
      await db.addMissingToPlaylist(fav, ['/a']);
      final copy = await db.duplicatePlaylist(fav, name: 'Fav copy', now: 2);
      final row = await (db.select(
        db.playlists,
      )..where((p) => p.id.equals(copy!))).getSingle();
      expect(row.kind, isNull);
      expect(await entries(copy!), [('/a', 0)]);
    });

    test('gone source gives null', () async {
      expect(await db.duplicatePlaylist(99, name: 'x', now: 1), isNull);
    });

    test('long name keeps the suffix within the limit', () async {
      final id = await db.createPlaylist('a' * 200, now: 1);
      final copy = await db.duplicatePlaylist(
        id,
        name: '${'a' * 200} (copy)',
        now: 2,
      );
      final name = (await db.playlistSummary(copy!))!.name;
      expect(name.length, 200);
      expect(name.endsWith(' (copy)'), isTrue);
    });
  });

  test('a blank duplicate name is a failed future', () async {
    final id = await db.createPlaylist('A', now: 1);
    await expectLater(
      db.duplicatePlaylist(id, name: ' ', now: 2),
      throwsArgumentError,
    );
  });

  test('duplicate name of emoji keeps the suffix, 200 graphemes', () async {
    final id = await db.createPlaylist('A', now: 1);
    final copy = await db.duplicatePlaylist(
      id,
      name: '${'\u{1F600}' * 200} (copy)',
      now: 2,
    );
    final name = (await db.playlistSummary(copy!))!.name;
    expect(name.characters.length, 200);
    expect(name.endsWith(' (copy)'), isTrue);
  });

  test('duplicate wakes the summaries watcher', () async {
    final id = await db.createPlaylist('A', now: 1);
    final lists = <int>[];
    final sub = db.watchPlaylistSummaries().listen((l) => lists.add(l.length));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.duplicatePlaylist(id, name: 'B', now: 2);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(lists, [1, 2]);
  });

  test('removing repeats wakes entry watchers', () async {
    final id = await db.createPlaylist('A', now: 1, paths: ['/a', '/a']);
    final events = <Set<TableUpdate>>[];
    final sub = db
        .tableUpdates(TableUpdateQuery.onTable(db.playlistEntries))
        .listen(events.add);
    await db.removeRepeatedEntries(id);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(events, isNotEmpty);
  });

  test('every name write cleans and limits', () async {
    final id = await db.createPlaylist('A\tB', now: 1);
    expect((await db.playlistSummary(id))!.name, 'AB');
    expect(() => db.createPlaylist('a' * 201, now: 1), throwsArgumentError);
    expect(
      () => db.addToPlaylists(
        paths: ['/a'],
        targets: const {},
        newNames: ['a' * 201],
        now: 1,
      ),
      throwsArgumentError,
    );
  });

  test('removeRepeatedEntries keeps the first copies and renumbers', () async {
    final id = await db.createPlaylist(
      'A',
      now: 1,
      paths: ['/a', '/b', '/a', '/c', '/b'],
    );
    final other = await db.createPlaylist('B', now: 1, paths: ['/a', '/a']);
    expect(await db.removeRepeatedEntries(id), 2);
    expect(await entries(id), [('/a', 0), ('/b', 1), ('/c', 2)]);
    expect(await entries(other), hasLength(2));
    expect(await db.removeRepeatedEntries(id), 0);
  });

  test('nothing repeated wakes no watcher', () async {
    final id = await db.createPlaylist('A', now: 1, paths: ['/a', '/b']);
    final events = <Set<TableUpdate>>[];
    final sub = db
        .tableUpdates(TableUpdateQuery.onTable(db.playlistEntries))
        .listen(events.add);
    await db.removeRepeatedEntries(id);
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    await sub.cancel();
  });
}
