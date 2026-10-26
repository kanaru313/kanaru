import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_browse_track_links.dart';
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

  /// Stores one track the way the indexer does and returns its id.
  Future<int> store({
    String? artist,
    String? album,
    String? albumArtist,
  }) async {
    final n = next++;
    final companion = TracksCompanion.insert(
      rootId: rootId,
      path: '/m/$n.flac',
      mtimeMs: 1,
      sizeBytes: 1,
      title: 'T$n',
      artist: Value(artist),
      album: Value(album),
      albumArtist: Value(albumArtist),
      addedAt: 1,
      updatedAt: 1,
    );
    await db.upsertTracks([companion]);
    return (await (db.select(
      db.tracks,
    )..where((t) => t.path.equals('/m/$n.flac'))).getSingle()).id;
  }

  test('one artist gives one link', () async {
    final id = await store(artist: 'Ann', album: 'Al');
    final links = await db.trackLinks(id);
    expect(links!.artists, [(key: 'ann', name: 'Ann')]);
  });

  test('several credited artists keep the tag order', () async {
    final id = await store(artist: 'Zed; Ann feat. Bob');
    final links = await db.trackLinks(id);
    expect([for (final a in links!.artists) a.name], ['Zed', 'Ann', 'Bob']);
  });

  test('no artist gives no links', () async {
    final id = await store(album: 'Al');
    expect((await db.trackLinks(id))!.artists, isEmpty);
  });

  test('no album title gives no album', () async {
    final id = await store(artist: 'Ann');
    expect((await db.trackLinks(id))!.album, isNull);
  });

  test('an unknown id gives null', () async {
    expect(await db.trackLinks(9999), isNull);
  });

  test('the album key is the one of the album page', () async {
    final id = await store(artist: 'Ann', album: 'Al', albumArtist: 'Ann');
    final key = (await db.trackLinks(id))!.album!;
    final onPage = await db.albumTracks(key);
    expect([for (final t in onPage) t.id], [id]);
  });

  group('trackMenuStateOfPath', () {
    test('reads the id and what the song links to', () async {
      final id = await store(artist: 'Ann', album: 'Al');

      expect(await db.trackMenuStateOfPath('/m/${next - 1}.flac'), (
        id: id,
        hasArtist: true,
        hasAlbum: true,
      ));
    });

    test('an empty artist and no album grey both links', () async {
      final id = await store(artist: '');

      expect(await db.trackMenuStateOfPath('/m/${next - 1}.flac'), (
        id: id,
        hasArtist: false,
        hasAlbum: false,
      ));
    });

    test('is null for a path outside the library', () async {
      await store(artist: 'Ann');

      expect(await db.trackMenuStateOfPath('/elsewhere/x.flac'), isNull);
    });
  });
}
