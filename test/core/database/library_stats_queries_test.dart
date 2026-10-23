import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_root_queries.dart';
import 'package:kanaru/core/database/library_stats_queries.dart';

late int _rootId;
var _next = 0;

/// A row as the indexer writes it (see `library_browse_queries_test.dart`).
TracksCompanion _row({
  String? artist,
  String? album,
  String? albumArtist,
  String? genre,
}) {
  final n = _next++;
  return TracksCompanion.insert(
    rootId: _rootId,
    path: '/m/$n.flac',
    mtimeMs: 1,
    sizeBytes: 1,
    title: 'T$n',
    artist: Value(artist),
    album: Value(album),
    albumArtist: Value(albumArtist),
    genre: Value(genre),
    addedAt: 1,
    updatedAt: 1,
  );
}

void main() {
  late LibraryDatabase db;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    _rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  test('an empty library counts zero', () async {
    expect(await db.libraryStats(), (tracks: 0, albums: 0, artists: 0));
  });

  test(
    'albums match the Albums list, tracks without an album excluded',
    () async {
      await db.upsertTracks([
        _row(artist: 'Ann', album: 'One'),
        _row(artist: 'Ann', album: 'One'),
        _row(artist: 'Ann'),
        // Same title, other album artist: another album.
        _row(artist: 'Bob', album: 'One', albumArtist: 'Bob'),
      ]);

      final stats = await db.libraryStats();
      expect(stats.tracks, 4);
      expect(stats.albums, 2);
      expect(stats.albums, (await db.albums()).length);
    },
  );

  test(
    'artists match the Artists list, a shared credit counted once',
    () async {
      await db.upsertTracks([_row(artist: 'Ann; Bob'), _row(artist: 'Ann')]);

      final stats = await db.libraryStats();
      expect(stats.artists, 2);
      expect(stats.artists, (await db.artistCredits()).length);
    },
  );

  test('removing the folder empties the counts', () async {
    await db.upsertTracks([_row(artist: 'Ann', album: 'One', genre: 'Rock')]);
    expect((await db.libraryStats()).tracks, 1);

    await db.removeRoot(_rootId);

    expect(await db.libraryStats(), (tracks: 0, albums: 0, artists: 0));
  });
}
