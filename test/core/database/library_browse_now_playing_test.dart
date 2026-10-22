import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_now_playing.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';

void main() {
  late LibraryDatabase db;
  late int rootId;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  Future<void> store(
    String path, {
    String? artist,
    String? album,
    String? albumArtist,
  }) => db.upsertTracks([
    TracksCompanion.insert(
      rootId: rootId,
      path: path,
      mtimeMs: 1,
      sizeBytes: 1,
      title: 'T',
      artist: Value(artist),
      album: Value(album),
      albumArtist: Value(albumArtist),
      addedAt: 1,
      updatedAt: 1,
    ),
  ]);

  test('gives the album text and the key of the album page', () async {
    await store('/m/a.flac', artist: 'Ann', album: 'Al', albumArtist: 'Ann');
    final album = await db.albumOfPath('/m/a.flac');
    expect(album!.title, 'Al');
    expect(
      [for (final t in await db.albumTracks(album.key!)) t.path],
      ['/m/a.flac'],
    );
  });

  test('a song without an album tag gives null', () async {
    await store('/m/a.flac', artist: 'Ann');
    expect(await db.albumOfPath('/m/a.flac'), isNull);
  });

  test('a blank album tag gives null', () async {
    await store('/m/a.flac', album: '  ');
    expect(await db.albumOfPath('/m/a.flac'), isNull);
  });

  test('a path outside the library gives null', () async {
    await store('/m/a.flac', album: 'Al');
    expect(await db.albumOfPath('/elsewhere/a.flac'), isNull);
  });

  test('an album without artist still has a key', () async {
    await store('/m/a.flac', album: 'Al');
    final album = await db.albumOfPath('/m/a.flac');
    expect(album!.key, isNotNull);
    expect(album.key!.artistKey, '');
  });
}
