import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_keys_backfill.dart';

import 'search_index_test_helpers.dart';

TracksCompanion _track(
  int rootId,
  String path, {
  String title = 'T',
  String? artist,
  String? album,
  String? albumArtist,
  String? genre,
  int mtimeMs = 1,
}) => TracksCompanion.insert(
  rootId: rootId,
  path: path,
  mtimeMs: mtimeMs,
  sizeBytes: 10,
  title: title,
  artist: Value(artist),
  album: Value(album),
  albumArtist: Value(albumArtist),
  genre: Value(genre),
  addedAt: 100,
  updatedAt: 100,
);

Future<int> _indexRows(LibraryDatabase db) async =>
    (await db
            .customSelect('SELECT count(*) AS n FROM track_search_data')
            .getSingle())
        .read<int>('n');

void main() {
  late LibraryDatabase db;
  late int rootId;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  Future<int> idOf(String path) async => (await (db.select(
    db.tracks,
  )..where((t) => t.path.equals(path))).getSingle()).id;

  test('the bundled SQLite has FTS5', () async {
    final row = await db
        .customSelect("SELECT sqlite_compileoption_used('ENABLE_FTS5') AS v")
        .getSingle();
    expect(row.read<int>('v'), 1);
  });

  test('a new track is indexed with its folded tags', () async {
    await db.upsertTracks([
      _track(
        rootId,
        '/m/a.flac',
        title: 'Đừng Làm',
        artist: 'Sơn Tùng M-TP',
        album: 'Sky Tour',
        albumArtist: 'Các Nghệ Sĩ',
        genre: 'Nhạc Trẻ',
      ),
    ]);
    final id = await idOf('/m/a.flac');
    for (final query in [
      'title_sort:dung',
      'artist_search:son',
      'artist_search:tung',
      'album_search:sky',
      'album_artist_search:nghe',
      'genre_search:nhac',
      'dung',
      'dun*',
    ]) {
      expect(await idsMatching(db, query), [id], reason: query);
    }
    expect(await idsMatching(db, 'đừng'), isEmpty);
    await expectSearchIndexIntact(db);
  });

  test('a rescan that changes a tag re-indexes the track', () async {
    await db.upsertTracks([_track(rootId, '/m/a.flac', artist: 'Old Band')]);
    final id = await idOf('/m/a.flac');
    await db.upsertTracks([
      _track(rootId, '/m/a.flac', artist: 'New Band', mtimeMs: 2),
    ]);
    expect(await idOf('/m/a.flac'), id);
    expect(await idsMatching(db, 'old'), isEmpty);
    expect(await idsMatching(db, 'new'), [id]);
    await expectSearchIndexIntact(db);
  });

  test('a rescan of an unchanged tag keeps the index intact', () async {
    final row = _track(rootId, '/m/a.flac', artist: 'Band', genre: 'Rock');
    await db.upsertTracks([row]);
    await db.upsertTracks([row]);
    expect(await idsMatching(db, 'band'), [await idOf('/m/a.flac')]);
    expect(await idsMatching(db, 'rock'), hasLength(1));
    await expectSearchIndexIntact(db);
  });

  test('a rescan of unchanged tags leaves the index data alone', () async {
    Future<List<String>> data() async => [
      for (final r
          in await db
              .customSelect(
                'SELECT id, hex(block) AS block FROM track_search_data ORDER BY id',
              )
              .get())
        '${r.read<int>('id')}:${r.read<String>('block')}',
    ];
    await db.upsertTracks([
      _track(rootId, '/m/a.flac', artist: 'Band', genre: 'Rock'),
    ]);
    final before = await data();
    await db.upsertTracks([
      _track(rootId, '/m/a.flac', artist: 'Band', genre: 'Rock', mtimeMs: 2),
    ]);
    expect(await data(), before);
    await db.upsertTracks([
      _track(rootId, '/m/a.flac', artist: 'Other', genre: 'Rock', mtimeMs: 3),
    ]);
    expect(await data(), isNot(before));
    expect(await idsMatching(db, 'other'), [await idOf('/m/a.flac')]);
    await expectSearchIndexIntact(db);
  });

  test('INSERT OR REPLACE on tracks keeps the index intact', () async {
    await db.upsertTracks([_track(rootId, '/m/a.flac', artist: 'Old Band')]);
    await db.customStatement(
      'INSERT OR REPLACE INTO tracks (root_id, path, mtime_ms, size_bytes, '
      "title, title_sort, artist_search, added_at, updated_at) "
      "VALUES ($rootId, '/m/a.flac', 2, 10, 'T', 't', 'new band', 1, 1)",
    );
    expect(await idsMatching(db, 'old'), isEmpty);
    expect(await idsMatching(db, 'new'), [await idOf('/m/a.flac')]);
    await expectSearchIndexIntact(db);
  });

  test('deleting tracks removes them from the index', () async {
    await db.upsertTracks([
      _track(rootId, '/m/a.flac', artist: 'Band'),
      _track(rootId, '/m/b.flac', artist: 'Band'),
    ]);
    final a = await idOf('/m/a.flac');
    final b = await idOf('/m/b.flac');
    await db.deleteTracksById([a]);
    expect(await idsMatching(db, 'band'), [b]);
    await expectSearchIndexIntact(db);
  });

  test('removing a root removes its tracks from the index', () async {
    final other = (await db.addRoots(['/o'], now: 1)).single;
    await db.upsertTracks([
      _track(rootId, '/m/a.flac', artist: 'Band'),
      _track(other, '/o/b.flac', artist: 'Band'),
    ]);
    await db.customStatement('DELETE FROM library_roots WHERE id = $rootId');
    expect(await idsMatching(db, 'band'), [await idOf('/o/b.flac')]);
    await expectSearchIndexIntact(db);
  });

  test('storing covers does not rewrite the index', () async {
    await db.upsertTracks([_track(rootId, '/m/a.flac', artist: 'Band')]);
    final id = await idOf('/m/a.flac');
    final before = await _indexRows(db);
    await db.writeCovers([(id, 'ab/cover.jpg')]);
    expect(await _indexRows(db), before);
    await db.resetCoverScan(['ab/cover.jpg']);
    expect(await _indexRows(db), before);
    expect(await idsMatching(db, 'band'), [id]);
    await expectSearchIndexIntact(db);
  });

  test('re-keying to a new version keeps the index intact', () async {
    await db.upsertTracks([
      _track(
        rootId,
        '/m/a.flac',
        title: 'Halo',
        artist: 'The Band',
        genre: 'Pop',
      ),
      _track(rootId, '/m/b.flac', title: 'Đen', artist: 'Anh', genre: 'Rap'),
    ]);
    expect(await backfillLibraryKeys(db, version: 3), 2);
    expect(await idsMatching(db, 'the'), [await idOf('/m/a.flac')]);
    expect(await idsMatching(db, 'den'), [await idOf('/m/b.flac')]);
    expect(await idsMatching(db, 'rap'), [await idOf('/m/b.flac')]);
    await expectSearchIndexIntact(db);
  });
}
