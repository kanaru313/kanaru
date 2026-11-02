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

  Future<void> addTrack(String path) async =>
      db.upsertTracks([track(root, path)]);

  test('stats count missing and repeated entries', () async {
    await addTrack('/a');
    final id = await db.createPlaylist(
      'A',
      now: 1,
      paths: ['/a', '/a', '/gone', '/gone', '/gone'],
    );
    final stats = await db.playlistModalStats(id);
    expect(stats.missing, 3);
    expect(stats.repeats, 3);
  });

  test('stats of an empty playlist are zeros', () async {
    final id = await db.createPlaylist('A', now: 1);
    final stats = await db.playlistModalStats(id);
    expect((stats.missing, stats.repeats), (0, 0));
  });

  test('missing ids delete only what was captured', () async {
    await addTrack('/a');
    await addTrack('/b');
    final id = await db.createPlaylist('A', now: 1, paths: ['/a', '/x', '/b']);
    final ids = await db.playlistMissingEntryIds(id);
    expect(ids, hasLength(1));
    // A track vanishes between the read and the tap.
    await (db.delete(db.tracks)..where((t) => t.path.equals('/b'))).go();
    await db.removePlaylistEntries(id, ids.toSet());
    final bId = (await (db.select(
      db.playlistEntries,
    )..where((e) => e.path.equals('/b'))).getSingle()).id;
    expect(ids, isNot(contains(bId)));
    expect(await db.playlistEntryPaths(id), ['/a', '/b']);
  });

  test('entry paths keep order, repeats and missing files', () async {
    final id = await db.createPlaylist('A', now: 1, paths: ['/b', '/a', '/b']);
    expect(await db.playlistEntryPaths(id), ['/b', '/a', '/b']);
    expect(await db.playlistEntryPaths(99), isEmpty);
  });
}
