import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart'
    show LibraryDatabase, TracksCompanion;
import 'package:kanaru/core/player/album_run_lookup.dart';

void main() {
  late LibraryDatabase db;
  late int rootId;

  TracksCompanion row(String name, {String? artist, String? album}) =>
      TracksCompanion.insert(
        rootId: rootId,
        path: '/m/$name.flac',
        mtimeMs: 1,
        sizeBytes: 1,
        title: name,
        artist: Value(artist),
        album: Value(album),
        albumArtist: Value(artist),
        addedAt: 1,
        updatedAt: 1,
      );

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  test(
    'reads the album key of each track, and only of those asked for',
    () async {
      await db.upsertTracks([
        row('a1', artist: 'Ann', album: 'One'),
        row('a2', artist: 'Ann', album: 'One'),
        row('a3', artist: 'Ann', album: 'One'),
        row('b1', artist: 'Bob', album: 'Two'),
        row('rest', artist: 'Ann'),
      ]);

      final keys = await albumKeyLookupFor(db)([
        '/m/a1.flac',
        '/m/a2.flac',
        '/m/b1.flac',
        '/m/missing.flac',
      ]);

      expect(keys.keys, {'/m/a1.flac', '/m/a2.flac', '/m/b1.flac'});
      expect(keys['/m/a1.flac'], keys['/m/a2.flac']);
      expect(keys['/m/a1.flac'], isNot(keys['/m/b1.flac']));
      expect(keys['/m/a1.flac']!.title, isNotEmpty);
    },
  );

  test('a track without an album has no key', () async {
    await db.upsertTracks([row('rest', artist: 'Ann')]);

    expect(await albumKeyLookupFor(db)(['/m/rest.flac']), isEmpty);
  });

  test('a row keyed under older rules has no key yet', () async {
    await db.upsertTracks([row('old', artist: 'Ann', album: 'One')]);
    await db.customStatement('UPDATE tracks SET keys_version = 0');

    expect(await albumKeyLookupFor(db)(['/m/old.flac']), isEmpty);
  });

  test('no paths, no query', () async {
    // A closed database would throw on any query.
    await db.close();

    expect(await albumKeyLookupFor(db)([]), isEmpty);
  });
}
