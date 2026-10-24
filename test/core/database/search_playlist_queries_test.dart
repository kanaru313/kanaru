import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/core/database/search_playlist_queries.dart';

import 'library_database_test.dart' show track;

void main() {
  late LibraryDatabase db;
  late int root;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    root = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  Future<void> addTracks(
    Map<String, ({String title, String? artist, String? album})> tracks,
  ) => db.upsertTracks([
    for (final e in tracks.entries)
      track(
        root,
        '/m/${e.key}',
        title: e.value.title,
        artist: e.value.artist,
      ).copyWith(album: Value(e.value.album)),
  ]);

  Future<List<int>> positions(int id, List<String> terms, {int? limit}) async {
    final matches = limit == null
        ? await db.playlistEntriesMatching(id, terms)
        : await db.playlistEntriesMatching(id, terms, limit: limit);
    return [for (final m in matches.entries) m.position];
  }

  Future<int> mix(List<String> files) =>
      db.createPlaylist('Mix', now: 1, paths: [for (final f in files) '/m/$f']);

  setUp(() async {
    await addTracks({
      'a': (title: 'Árbol Verde', artist: 'Ana', album: 'Selva'),
      'b': (title: 'Blue', artist: 'Verdi', album: 'Opera'),
      'c': (title: 'Cielo', artist: 'Ana', album: 'Verde Mar'),
      'd': (title: 'Dawn', artist: 'Zed', album: null),
    });
  });

  test('matches title, artist and album with folded accents', () async {
    final id = await mix(['a', 'b', 'c', 'd']);

    expect(await positions(id, ['verd']), [0, 1, 2]);
    expect(await positions(id, ['arbol', 'verde']), [0]);
    expect(await positions(id, ['ana', 'verde']), [0, 2]);
    expect(await positions(id, ['opera', 'verde']), isEmpty);
    expect(await positions(id, ['zzz']), isEmpty);
  });

  test('no terms gives nothing', () async {
    final id = await mix(['a']);

    expect((await db.playlistEntriesMatching(id, const [])).entries, isEmpty);
  });

  test('a song listed twice comes back once per entry, by position', () async {
    final id = await mix(['c', 'a', 'c']);

    final matches = await db.playlistEntriesMatching(id, ['verd']);

    expect(matches.entries.map((m) => m.position), [0, 1, 2]);
    expect(matches.entries.map((m) => m.entry.track!.title), [
      'Cielo',
      'Árbol Verde',
      'Cielo',
    ]);
    expect(matches.entries.map((m) => m.entry.entryId).toSet(), hasLength(3));
  });

  test('an entry whose file is not in the library never matches', () async {
    final id = await mix(['gone', 'a']);

    expect(await positions(id, ['verd']), [1]);
    expect(await positions(id, ['gone']), isEmpty);
  });

  test('only looks inside the asked playlist', () async {
    final id = await mix(['a']);
    await db.createPlaylist('Other', now: 2, paths: ['/m/c']);

    expect(await positions(id, ['verd']), [0]);
  });

  test('is cut at the limit and says so', () async {
    final id = await mix(['a', 'b', 'c']);

    final cut = await db.playlistEntriesMatching(id, ['verd'], limit: 2);
    expect(cut.entries.map((m) => m.position), [0, 1]);
    expect(cut.truncated, isTrue);

    final exact = await db.playlistEntriesMatching(id, ['verd'], limit: 3);
    expect(exact.entries, hasLength(3));
    expect(exact.truncated, isFalse);
  });
}
