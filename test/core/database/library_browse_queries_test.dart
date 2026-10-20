import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_sql_functions.dart';

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
  String? coverKey,
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
    coverKey: Value(coverKey),
  );
}

void main() {
  late LibraryDatabase db;

  setUp(() async {
    db = LibraryDatabase(
      NativeDatabase.memory(setup: registerLibrarySqlFunctions),
    );
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

    test('splits same titles of different artists, folds case', () async {
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
      // Keys use Dart's Unicode lower case: these spellings merge too.
      final unicode = all[const AlbumKey('c', 'ánh')]!;
      expect(unicode.trackCount, 2);
      expect(await db.watchAlbumTracks(unicode.key).first, hasLength(2));
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
    test('credits come from the artist column only', () async {
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
      expect(ann.trackCount, 3);
      expect(ann.albumKeys, {const AlbumKey('ann', 'x')});
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
      expect(ann.firstWhere((t) => t.title == 'guest').albumKey, isNull);

      final wild = await db.watchArtistTracks("50% _off's").first;
      expect(wild.single.title, 'wild');
      expect(await db.watchArtistTracks('%').first, isEmpty);
      expect(await db.watchArtistTracks('_').first, isEmpty);
    });
  });

  group('real tags', () {
    test('several artists in one tag, however written', () async {
      await db.upsertTracks([
        row(
          title: 'Khi Cô Đơn Em Nhớ Đến Ai',
          artist: 'Ban nhạc Hương Mùa Hè;SUNI Hạ Linh',
        ),
        row(
          title: 'one',
          artist: 'Chau Khai Phong',
          album: 'Châu Khải Phong Best Collection',
        ),
        row(
          title: 'two',
          artist: 'Chau Khai Phong feat. Trịnh Đình Quang',
          album: 'Châu Khải Phong Best Collection',
        ),
        row(title: 'acdc', artist: 'AC/DC feat. X', album: 'Live'),
      ]);
      final all = await albums();
      final best = all.values.singleWhere(
        (a) => a.title == 'Châu Khải Phong Best Collection',
      );
      expect(best.trackCount, 2, reason: 'a feat. track stays in the album');
      expect(best.key.artistKey, 'chau khai phong');
      expect(best.artist, 'Chau Khai Phong');
      expect(all.keys, contains(const AlbumKey('ac/dc', 'live')));

      final suni = await db.watchArtistTracks('suni hạ linh').first;
      expect(suni.single.title, 'Khi Cô Đơn Em Nhớ Đến Ai');
      final guest = await db.watchArtistTracks('trịnh đình quang').first;
      expect(guest.single.title, 'two');
      expect(await db.watchArtistTracks('suni').first, isEmpty);
    });

    test('an album artist naming several artists keys them all', () async {
      await db.upsertTracks([
        row(artist: 'A', album: 'Duo', albumArtist: 'A / B'),
        row(artist: 'B', album: 'Duo', albumArtist: 'A/B'),
      ]);
      expect((await albums()).keys, [const AlbumKey('a; b', 'duo')]);
    });
  });

  group('hostile tags', () {
    test('delimiter characters in tags do not break the queries', () async {
      await db.upsertTracks([
        row(artist: 'A\u001eB', album: 'X\u001fY'),
        row(artist: 'Z\u00000\u0000', album: 'Q'),
      ]);
      final credits = await db.watchArtistCredits().first;
      expect(credits, hasLength(2));
      final keys = {for (final c in credits) ...c.albumKeys};
      expect(keys, contains(const AlbumKey('a b', 'x y')));
      expect(
        await db.watchAlbumTracks(const AlbumKey('a b', 'x y')).first,
        hasLength(1),
      );
      expect((await albums()).keys, contains(const AlbumKey('z 0', 'q')));
    });

    test('album artists with long names keep every key whole', () async {
      final long = 'n' * 300;
      await db.upsertTracks([
        row(artist: 'B', album: 'Duo', albumArtist: '$long; B'),
      ]);
      final key = (await albums()).keys.single;
      expect(key.artistKeys, ['n' * 256, 'b']);
      expect(await db.watchArtistTracks('b').first, hasLength(1));
    });
  });

  test('the artist page keeps each album together', () async {
    await db.upsertTracks([
      row(title: 'z1', artist: 'A', album: 'Zeta', year: 2000, track: 1),
      row(title: 'e1', artist: 'A', album: 'Éclair', year: 2000, track: 1),
      row(title: 'z2', artist: 'A', album: 'zeta', year: 2000, track: 2),
      row(title: 'e2', artist: 'A', album: 'éclair', year: 2000, track: 2),
      // ASCII lower() would sort Ñu between Éclair and éclair.
      row(title: 'n1', artist: 'A', album: 'Ñu', year: 2000, track: 1),
    ]);
    final titles = [
      for (final t in await db.watchArtistTracks('a').first) t.title,
    ];
    // Ordered by the Unicode title key, so case variants stay adjacent.
    expect(titles, ['z1', 'z2', 'e1', 'e2', 'n1']);
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

  group('cover keys', () {
    test('an album takes the smallest cover key among its tracks', () async {
      await db.upsertTracks([
        row(artist: 'A', album: 'X', coverKey: 'cd/cd.jpg'),
        row(artist: 'A', album: 'X'),
        row(artist: 'A', album: 'X', coverKey: 'ab/ab.jpg'),
        // Another spelling of the same album key still counts.
        row(artist: 'a', album: 'x', coverKey: 'aa/aa.jpg'),
        row(artist: 'B', album: 'Y'),
      ]);
      final all = await albums();
      expect(all[const AlbumKey('a', 'x')]!.coverKey, 'aa/aa.jpg');
      expect(all[const AlbumKey('b', 'y')]!.coverKey, isNull);
    });

    test('songs, album tracks and artist tracks carry the key', () async {
      await db.upsertTracks([
        row(title: 'With', artist: 'A', album: 'X', coverKey: 'ab/ab.jpg'),
        row(title: 'Without', artist: 'A', album: 'X'),
      ]);
      Map<String, String?> byTitle(Iterable<(String, String?)> rows) => {
        for (final (title, key) in rows) title: key,
      };
      const expected = {'With': 'ab/ab.jpg', 'Without': null};
      final songs = await db.watchSongs().first;
      expect(byTitle(songs.map((t) => (t.title, t.coverKey))), expected);
      final album = await db.albumTracks(const AlbumKey('a', 'x'));
      expect(byTitle(album.map((t) => (t.title, t.coverKey))), expected);
      final artist = await db.artistTracks('a');
      expect(byTitle(artist.map((t) => (t.title, t.coverKey))), expected);
      final items = await db.watchTrackListItems().first;
      expect(byTitle(items.map((t) => (t.title, t.coverKey))), expected);
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
