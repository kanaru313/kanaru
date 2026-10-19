import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';

late int _rootId;
var _next = 0;

/// A row as the indexer writes it: trimmed, empty means null, several track
/// artists joined with "; ", one album artist.
TracksCompanion row({
  String? title,
  String? artist,
  String? album,
  String? albumArtist,
  int? year,
  int? disc,
  int? track,
  int? durationMs,
  int addedAt = 1,
}) {
  final n = _next++;
  return TracksCompanion.insert(
    rootId: _rootId,
    path: '/m/$n.flac',
    mtimeMs: 1,
    sizeBytes: 1,
    title: title ?? 'T$n',
    artist: Value(artist),
    album: Value(album),
    albumArtist: Value(albumArtist),
    year: Value(year),
    discNo: Value(disc),
    trackNo: Value(track),
    durationMs: Value(durationMs),
    addedAt: addedAt,
    updatedAt: addedAt,
  );
}

void main() {
  late LibraryDatabase db;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    _rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  Future<Map<AlbumKey, AlbumSummary>> albums() async => {
    for (final a in await db.watchAlbums().first) a.key: a,
  };

  group('albums', () {
    test('keys by album artist, else the first track artist', () async {
      await db.upsertTracks([
        row(artist: 'A', album: 'X'),
        row(artist: 'A; B', album: 'X'),
        row(artist: 'B; A', album: 'X'),
        row(artist: 'Z', album: 'Y', albumArtist: 'Various Artists'),
        row(artist: 'Q', album: 'Y', albumArtist: 'Various Artists'),
      ]);
      final all = await albums();
      expect(all.keys, {
        const AlbumKey('a', 'x'),
        // A guest listed first splits the album (no compilation heuristic).
        const AlbumKey('b', 'x'),
        const AlbumKey('various artists', 'y'),
      });
      expect(all[const AlbumKey('a', 'x')]!.trackCount, 2);
      expect(all[const AlbumKey('a', 'x')]!.artist, 'A');
      expect(all[const AlbumKey('various artists', 'y')]!.trackCount, 2);
    });

    test('splits same titles of different artists, folds ASCII case', () async {
      await db.upsertTracks([
        row(artist: 'A', album: 'Same'),
        row(artist: 'B', album: 'Same'),
        row(artist: 'Beatles', album: 'Abbey Road'),
        row(artist: 'beatles', album: 'abbey road'),
        row(artist: 'C', album: 'Ánh'),
        row(artist: 'C', album: 'ánh'),
      ]);
      final all = await albums();
      expect(all.keys, contains(const AlbumKey('a', 'same')));
      expect(all.keys, contains(const AlbumKey('b', 'same')));
      final abbey = all[const AlbumKey('beatles', 'abbey road')]!;
      expect(abbey.trackCount, 2);
      expect(abbey.title, 'Abbey Road');
      // lower() is ASCII only: the Unicode spellings stay apart.
      final unicode = all.values.where((a) => a.key.artistKey == 'c');
      expect(unicode, hasLength(2));
      for (final album in unicode) {
        final tracks = await db.watchAlbumTracks(album.key).first;
        expect(tracks.single.album, album.title);
      }
    });

    test(
      'drops tracks without an album, keeps albums without artist',
      () async {
        await db.upsertTracks([row(artist: 'A'), row(album: 'Disc 1')]);
        final all = await albums();
        expect(all.keys, [const AlbumKey('', 'disc 1')]);
        expect(all.values.single.artist, isNull);
      },
    );

    test('aggregates year, count, duration and added time', () async {
      await db.upsertTracks([
        row(artist: 'A', album: 'X', year: 1999, durationMs: 100, addedAt: 5),
        row(artist: 'A', album: 'X', year: 2001, addedAt: 9),
        row(artist: 'A', album: 'X', durationMs: 50, addedAt: 7),
        row(artist: 'A', album: 'N'),
      ]);
      final all = await albums();
      final x = all[const AlbumKey('a', 'x')]!;
      expect(x.year, 2001);
      expect(x.trackCount, 3);
      expect(x.durationMs, 150);
      expect(x.addedAt, 9);
      expect(all[const AlbumKey('a', 'n')]!.durationMs, isNull);
    });

    test(
      'cuts long keys to 256 characters and still finds the tracks',
      () async {
        final long = 'L' * 1000;
        await db.upsertTracks([
          row(artist: long, album: long),
          row(artist: long, album: long),
        ]);
        final album = (await albums()).values.single;
        expect(album.key.titleKey, 'l' * 256);
        expect(album.key.artistKey, 'l' * 256);
        expect(await db.watchAlbumTracks(album.key).first, hasLength(2));
      },
    );
  });

  test('album and artist pages order discs and tracks alike', () async {
    await db.upsertTracks([
      row(title: 'd-null', artist: 'A', album: 'X', track: 1),
      row(title: 't-null', artist: 'A', album: 'X', disc: 1),
      row(title: 'd2t1', artist: 'A', album: 'X', disc: 2, track: 1),
      row(title: 'd1t2', artist: 'A', album: 'X', disc: 1, track: 2),
      row(title: 'd1t1', artist: 'A', album: 'X', disc: 1, track: 1),
    ]);
    const expected = ['d1t1', 'd1t2', 't-null', 'd2t1', 'd-null'];
    final album = await db.watchAlbumTracks(const AlbumKey('a', 'x')).first;
    expect(album.map((t) => t.title), expected);
    final artist = await db.watchArtistTracks('a').first;
    expect(artist.map((t) => t.title), expected);
  });

  group('artists', () {
    test('credits come from the artist column with SQL keys', () async {
      await db.upsertTracks([
        row(artist: 'Ann; Bob', album: 'X'),
        row(artist: 'Ann; Bob', album: 'X'),
        row(artist: 'Ann; Bob'),
        row(artist: 'ÁNN', album: 'Y', albumArtist: 'Various Artists'),
        row(album: 'Z', albumArtist: 'Only Album Artist'),
      ]);
      final credits = {
        for (final c in await db.watchArtistCredits().first) c.artist: c,
      };
      expect(credits.keys, {'Ann; Bob', 'ÁNN'});
      final ann = credits['Ann; Bob']!;
      expect(ann.artistKey, 'ann; bob');
      expect(ann.trackCount, 3);
      expect(ann.albumKeys, {const AlbumKey('ann', 'x')});
      expect(credits['ÁNN']!.artistKey, 'Ánn');
      expect(credits['ÁNN']!.albumKeys, {
        const AlbumKey('various artists', 'y'),
      });
    });

    test('artist tracks match whole names in the artist column only', () async {
      await db.upsertTracks([
        row(title: 'ann', artist: 'Ann', album: 'X'),
        row(title: 'guest', artist: 'X; Ann'),
        row(title: 'anna', artist: 'Anna'),
        row(title: 'aa', artist: 'Z', albumArtist: 'Ann', album: 'Y'),
        row(title: 'wild', artist: '50% _Off\'s'),
      ]);
      final ann = await db.watchArtistTracks('ann').first;
      expect(ann.map((t) => t.title), unorderedEquals(['ann', 'guest']));
      final withAlbum = ann.firstWhere((t) => t.title == 'ann');
      expect(withAlbum.albumKey, const AlbumKey('ann', 'x'));
      expect(withAlbum.artistKeys, 'ann');
      expect(ann.firstWhere((t) => t.title == 'guest').albumKey, isNull);

      final wild = await db.watchArtistTracks("50% _off's").first;
      expect(wild.single.title, 'wild');
      expect(await db.watchArtistTracks('%').first, isEmpty);
      expect(await db.watchArtistTracks('_').first, isEmpty);
    });
  });

  group('songs', () {
    setUp(() async {
      await db.upsertTracks([
        row(
          title: 'b',
          artist: 'Y',
          album: 'P',
          year: 2000,
          durationMs: 3,
          addedAt: 3,
        ),
        row(title: 'a', artist: 'X', year: 1990, durationMs: 9, addedAt: 1),
        row(title: 'C', album: 'Q', durationMs: 1, addedAt: 2),
        row(title: 'd', artist: 'x', album: 'p', year: 2000, addedAt: 4),
      ]);
    });

    Future<List<String>> titles(SongOrder order, {bool desc = false}) async => [
      for (final t in await db.watchSongs(order: order, descending: desc).first)
        t.title,
    ];

    test('orders by each field, unknown values last both ways', () async {
      expect(await titles(SongOrder.title), ['a', 'b', 'C', 'd']);
      expect(await titles(SongOrder.title, desc: true), ['d', 'C', 'b', 'a']);
      expect(await titles(SongOrder.artist), ['a', 'd', 'b', 'C']);
      expect(await titles(SongOrder.artist, desc: true), ['b', 'a', 'd', 'C']);
      expect(await titles(SongOrder.album), ['b', 'd', 'C', 'a']);
      expect(await titles(SongOrder.album, desc: true), ['C', 'b', 'd', 'a']);
      expect(await titles(SongOrder.year), ['a', 'b', 'd', 'C']);
      expect(await titles(SongOrder.year, desc: true), ['b', 'd', 'a', 'C']);
      expect(await titles(SongOrder.dateAdded), ['a', 'C', 'b', 'd']);
      expect(await titles(SongOrder.dateAdded, desc: true), [
        'd',
        'b',
        'C',
        'a',
      ]);
      expect(await titles(SongOrder.duration), ['C', 'b', 'a', 'd']);
      expect(await titles(SongOrder.duration, desc: true), [
        'a',
        'b',
        'C',
        'd',
      ]);
    });

    test('the default order matches watchTrackListItems', () async {
      final songs = await db.watchSongs().first;
      final items = await db.watchTrackListItems().first;
      expect(songs.map((t) => t.id), items.map((t) => t.id));
      expect(songs.first.artist, items.first.artist);
      expect(songs.first.path, items.first.path);
    });
  });

  test('watchers re-emit when tracks change', () async {
    final emitted = <int>[];
    final sub = db.watchAlbums().listen((a) => emitted.add(a.length));
    await pumpEventQueue();
    await db.upsertTracks([row(artist: 'A', album: 'X')]);
    await pumpEventQueue();
    await sub.cancel();
    expect(emitted, [0, 1]);
  });
}
