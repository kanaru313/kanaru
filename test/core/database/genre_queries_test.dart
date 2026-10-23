import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../stats/gated_query_interceptor.dart';

import 'package:kanaru/core/database/genre_queries.dart';
import 'package:kanaru/core/database/library_database.dart';

void main() {
  late LibraryDatabase db;
  late int rootId;
  var next = 0;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  Future<void> store(
    String title, {
    String? genre,
    String? album,
    String? albumArtist,
  }) => db.upsertTracks([
    TracksCompanion.insert(
      rootId: rootId,
      path: '/m/${next++}.flac',
      mtimeMs: 1,
      sizeBytes: 1,
      title: title,
      genre: Value(genre),
      album: Value(album),
      albumArtist: Value(albumArtist),
      addedAt: 1,
      updatedAt: 1,
    ),
  ]);

  test('counts every stored string, spellings apart, and null', () async {
    await store('a', genre: 'Rock');
    await store('b', genre: 'Rock');
    await store('c', genre: 'rock');
    await store('d');

    final counts = await db.genreCounts();

    expect(
      {for (final c in counts) c.raw: c.count},
      {'Rock': 2, 'rock': 1, null: 1},
    );
  });

  test('tracks of the given strings come by title', () async {
    await store('b', genre: 'Rock');
    await store('a', genre: 'rock');
    await store('c', genre: 'Jazz');

    final tracks = await db.genreTracks(['Rock', 'rock']);

    expect([for (final t in tracks) t.title], ['a', 'b']);
  });

  test('albums are summed over all their tracks', () async {
    await store('r', genre: 'Rock', album: 'Mixed', albumArtist: 'X');
    await store('j', genre: 'Jazz', album: 'Mixed', albumArtist: 'X');
    await store('o', genre: 'Jazz', album: 'Other', albumArtist: 'X');
    await store('n', genre: 'Rock');

    final albums = await db.genreAlbums(['Rock']);

    expect([for (final a in albums) a.title], ['Mixed']);
    expect(albums.single.trackCount, 2);
  });

  test('no strings give nothing and run no SQL', () async {
    await db.close();
    final gate = GatedQueryInterceptor();
    db = LibraryDatabase(NativeDatabase.memory().interceptWith(gate));
    rootId = (await db.addRoots(['/m'], now: 1)).single;
    await store('a', genre: 'Rock');
    final before = gate.statements.length;

    expect(await db.genreTracks(const []), isEmpty);
    expect(await db.genreAlbums(const []), isEmpty);

    expect(gate.statements.length, before, reason: 'no statement was run');
  });

  test('a string with SQL characters is only a value', () async {
    await store('a', genre: "R'n'B; --");

    expect(await db.genreTracks(["R'n'B; --"]), hasLength(1));
    expect(await db.genreTracks(["R'n'B"]), isEmpty);
  });

  group('tracks without a genre', () {
    test('tracks come with the strings, or alone', () async {
      await store('b', genre: 'Rock');
      await store('a');
      await store('c', genre: '');
      await store('d', genre: 'Jazz');

      Future<List<String>> titles(List<String> raws, bool nulls) async => [
        for (final t in await db.genreTracks(raws, includeNull: nulls)) t.title,
      ];

      expect(await titles(['Rock'], true), ['a', 'b']);
      expect(await titles(const [], true), ['a']);
      expect(await titles(['', 'Rock'], true), ['a', 'b', 'c']);
      expect(await titles(['Rock'], false), ['b']);
      expect(await titles(const [], false), isEmpty);
    });

    test('albums count when one track has no genre', () async {
      await store('r', genre: 'Rock', album: 'Mixed', albumArtist: 'X');
      await store('n', album: 'Mixed', albumArtist: 'X');
      await store('o', genre: 'Jazz', album: 'Other', albumArtist: 'X');
      await store('m', album: 'NoGenre', albumArtist: 'X');

      final albums = await db.genreAlbums(const [], includeNull: true);

      expect([for (final a in albums) a.title]..sort(), ['Mixed', 'NoGenre']);
      expect(albums.firstWhere((a) => a.title == 'Mixed').trackCount, 2);
    });

    test('no strings and no nulls run no SQL', () async {
      await db.close();
      final gate = GatedQueryInterceptor();
      db = LibraryDatabase(NativeDatabase.memory().interceptWith(gate));
      rootId = (await db.addRoots(['/m'], now: 1)).single;
      await store('a');
      final before = gate.statements.length;

      expect(await db.genreTracks(const []), isEmpty);
      expect(await db.genreAlbums(const []), isEmpty);
      expect(gate.statements.length, before);
      expect(await db.genreTracks(const [], includeNull: true), hasLength(1));
    });
  });
}
