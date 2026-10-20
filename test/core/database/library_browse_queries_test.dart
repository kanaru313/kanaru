import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/text_keys.dart';

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
    db = LibraryDatabase(NativeDatabase.memory());
    _rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  Future<Map<AlbumKey, AlbumSummary>> albums() async => {
    for (final a in await db.albums()) a.key: a,
  };

  group('album rows', () {
    setUp(() async {
      await db.upsertTracks([
        row(artist: 'Ann; Bob', album: 'The Duo', year: 1999, coverKey: 'b'),
        row(artist: 'Ann', album: 'The Duo', year: 2003, coverKey: 'a'),
        row(artist: 'Bob', album: 'Other'),
      ]);
    });

    test('one album and the albums of an artist share the list rows', () async {
      final list = {for (final a in await db.albums()) a.key: a};
      const duo = AlbumKey('ann', 'the duo');

      final one = (await db.album(duo))!;
      expect(one.title, 'The Duo');
      expect(one.artist, 'Ann');
      expect(one.year, 2003);
      expect(one.trackCount, 2);
      expect(one.coverKey, 'a');
      expect(one.titleSort, 'duo');
      expect(one.titleSort, list[duo]!.titleSort);

      // Bob's tracks reach both albums; each row counts every track.
      final bobs = await db.artistAlbums('bob');
      expect(
        {for (final a in bobs) a.key},
        {duo, const AlbumKey('bob', 'other')},
      );
      expect(bobs.firstWhere((a) => a.key == duo).trackCount, 2);
      expect(await db.album(const AlbumKey('nobody', 'nothing')), isNull);
      expect(await db.artistAlbums('nobody'), isEmpty);
    });
  });

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
      expect(await db.albumTracks(unicode.key), hasLength(2));
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
        expect(await db.albumTracks(album.key), hasLength(2));
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
    final album = await db.albumTracks(const AlbumKey('a', 'x'));
    expect(album.map((t) => t.title), expected);
    final artist = await db.artistTracks('a');
    expect(artist.map((t) => t.title), expected);
  });

  group('artists', () {
    test('credits come from the artist column, split into names', () async {
      await db.upsertTracks([
        row(artist: 'Ann; Bob', album: 'X'),
        row(artist: 'Ann; Bob', album: 'X'),
        row(artist: 'Ann; Bob'),
        row(artist: 'ÁNN', album: 'Y', albumArtist: 'Various Artists'),
        row(artist: 'Ann', album: 'Y'),
        row(album: 'Z', albumArtist: 'Only Album Artist'),
      ]);
      final credits = {for (final c in await db.artistCredits()) c.key: c};
      // 'ÁNN' and 'Ann' are two artists: accents are kept in keys.
      expect(credits.keys, {'ann', 'bob', 'ánn'});
      final ann = credits['ann']!;
      expect(ann.name, 'Ann');
      expect(ann.trackCount, 4);
      expect(ann.albumCount, 2);
      expect(credits['bob']!.trackCount, 3);
      expect(credits['bob']!.albumCount, 1);
      expect(credits['ánn']!.name, 'ÁNN');
      expect(credits['ánn']!.albumCount, 1);
    });

    test('an artist named twice in one tag counts each track once', () async {
      await db.upsertTracks([row(artist: 'Ann; ANN', album: 'X')]);
      final credit = (await db.artistCredits()).single;
      expect(credit.trackCount, 1);
      expect(credit.name, 'Ann', reason: 'the first spelling on the track');
    });

    test('artist tracks match whole names in the artist column only', () async {
      await db.upsertTracks([
        row(title: 'ann', artist: 'Ann', album: 'X'),
        row(title: 'guest', artist: 'X; Ann'),
        row(title: 'anna', artist: 'Anna'),
        row(title: 'aa', artist: 'Z', albumArtist: 'Ann', album: 'Y'),
        row(title: 'wild', artist: '50% _Off\'s'),
      ]);
      final ann = await db.artistTracks('ann');
      expect(ann.map((t) => t.title), unorderedEquals(['ann', 'guest']));
      final withAlbum = ann.firstWhere((t) => t.title == 'ann');
      expect(withAlbum.albumKey, const AlbumKey('ann', 'x'));
      expect(ann.firstWhere((t) => t.title == 'guest').albumKey, isNull);

      final wild = await db.artistTracks("50% _off's");
      expect(wild.single.title, 'wild');
      expect(await db.artistTracks('%'), isEmpty);
      expect(await db.artistTracks('_'), isEmpty);
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

      final suni = await db.artistTracks('suni hạ linh');
      expect(suni.single.title, 'Khi Cô Đơn Em Nhớ Đến Ai');
      final guest = await db.artistTracks('trịnh đình quang');
      expect(guest.single.title, 'two');
      expect(await db.artistTracks('suni'), isEmpty);
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
      final credits = await db.artistCredits();
      expect(credits, hasLength(2));
      expect(await db.albumTracks(const AlbumKey('a b', 'x y')), hasLength(1));
      expect((await albums()).keys, contains(const AlbumKey('z 0', 'q')));
    });

    test('album artists with long names keep every key whole', () async {
      final long = 'n' * 300;
      await db.upsertTracks([
        row(artist: 'B', album: 'Duo', albumArtist: '$long; B'),
      ]);
      final key = (await albums()).keys.single;
      expect(key.artistKeys, ['n' * 256, 'b']);
      expect(await db.artistTracks('b'), hasLength(1));
    });
  });

  test('the artist page keeps each album together', () async {
    await db.upsertTracks([
      row(title: 'z1', artist: 'A', album: 'Zeta', year: 2000, track: 1),
      row(title: 'e1', artist: 'A', album: 'Éclair', year: 2000, track: 1),
      row(title: 'z2', artist: 'A', album: 'zeta', year: 2000, track: 2),
      row(title: 'e2', artist: 'A', album: 'éclair', year: 2000, track: 2),
      row(title: 'n1', artist: 'A', album: 'Ñu', year: 2000, track: 1),
    ]);
    final titles = [for (final t in await db.artistTracks('a')) t.title];
    // Ordered by the album's sort key: case variants stay adjacent and
    // accented names sit in their alphabet position (Éclair, Ñu, Zeta).
    expect(titles, ['e1', 'e2', 'n1', 'z1', 'z2']);
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
      for (final t in await db.songs(order: order, descending: desc)) t.title,
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
      final songs = await db.songs();
      expect(byTitle(songs.map((t) => (t.title, t.coverKey))), expected);
      final album = await db.albumTracks(const AlbumKey('a', 'x'));
      expect(byTitle(album.map((t) => (t.title, t.coverKey))), expected);
      final artist = await db.artistTracks('a');
      expect(byTitle(artist.map((t) => (t.title, t.coverKey))), expected);
    });
  });

  group('write path', () {
    Future<List<(String, String)>> credited(int trackId) async => [
      for (final r
          in await db
              .customSelect(
                'SELECT artist_key, artist_name FROM track_artists '
                'WHERE track_id = ? ORDER BY artist_key',
                variables: [Variable.withInt(trackId)],
              )
              .get())
        (r.read<String>('artist_key'), r.read<String>('artist_name')),
    ];

    test('a new track is stored with keys and credits', () async {
      await db.upsertTracks([
        row(title: 'Đen', artist: 'The Ánh; ĐEN', album: 'The Best'),
      ]);
      final t = await db.select(db.tracks).getSingle();
      expect(t.keysVersion, textKeysVersion);
      expect(t.titleSort, 'den');
      expect(t.artistSort, 'anh; den');
      expect(t.albumSort, 'best');
      expect(t.albumArtistKey, 'the ánh');
      expect(t.albumTitleKey, 'the best');
      expect(t.albumDisplayArtist, 'The Ánh');
      expect(await credited(t.id), [('the ánh', 'The Ánh'), ('đen', 'ĐEN')]);
    });

    test('a rescan that changes the tags re-keys the track', () async {
      final first = row(title: 'Old', artist: 'Ann; Bob', album: 'X');
      await db.upsertTracks([first]);
      final id = (await db.select(db.tracks).getSingle()).id;

      // Same path, new tags: as a rescan of a re-tagged file writes it.
      await db.upsertTracks([
        first.copyWith(
          title: const Value('Émile'),
          artist: const Value('Cat'),
          album: const Value('Y'),
        ),
      ]);

      final t = await db.select(db.tracks).getSingle();
      expect(t.id, id);
      expect(t.titleSort, 'emile');
      expect(t.artistSort, 'cat');
      expect(t.albumTitleKey, 'y');
      expect(t.albumArtistKey, 'cat');
      expect(await credited(id), [('cat', 'Cat')]);
      expect((await db.albums()).map((a) => a.key), [
        const AlbumKey('cat', 'y'),
      ]);
      expect(await db.artistTracks('bob'), isEmpty);
    });

    test('dropping the artist and album clears their keys', () async {
      final first = row(artist: 'Ann', album: 'X');
      await db.upsertTracks([first]);
      await db.upsertTracks([
        first.copyWith(artist: const Value(null), album: const Value(null)),
      ]);
      final t = await db.select(db.tracks).getSingle();
      expect(t.artistSort, isNull);
      expect(t.albumTitleKey, isNull);
      expect(await credited(t.id), isEmpty);
    });

    test('a tag left out of the row is stored empty, keys included', () async {
      final first = row(artist: 'Ann', album: 'X');
      await db.upsertTracks([first]);
      await db.upsertTracks([
        TracksCompanion.insert(
          rootId: first.rootId.value,
          path: first.path.value,
          mtimeMs: 1,
          sizeBytes: 1,
          title: 'Again',
          addedAt: 1,
          updatedAt: 1,
        ),
      ]);
      final t = await db.select(db.tracks).getSingle();
      expect(t.artist, isNull);
      expect(t.artistSort, isNull);
      expect(t.albumTitleKey, isNull);
    });

    test('deleting a track deletes its credits', () async {
      await db.upsertTracks([row(artist: 'Ann; Bob')]);
      final id = (await db.select(db.tracks).getSingle()).id;
      await db.deleteTracksById([id]);
      expect(await credited(id), isEmpty);
    });
  });

  group('query plans', () {
    Future<String> plan(String sql, [List<Variable> vars = const []]) async {
      final rows = await db
          .customSelect('EXPLAIN QUERY PLAN $sql', variables: vars)
          .get();
      return rows.map((r) => r.read<String>('detail')).join('\n');
    }

    test('albums group over the album key index, no temp tree', () async {
      final details = await plan(albumsSql);
      expect(details, contains('USING INDEX tracks_album_key'));
      expect(details, isNot(contains('TEMP B-TREE')));
    });

    test('an album page searches the album key index', () async {
      final details = await plan(albumTracksSql, [
        Variable.withString('a'),
        Variable.withString('x'),
      ]);
      expect(details, contains('SEARCH t USING INDEX tracks_album_key'));
      expect(details, contains('album_artist_key=?'));
      expect(details, contains('album_title_key=?'));
    });

    test('an artist page searches track_artists by key', () async {
      final details = await plan(artistTracksSql, [Variable.withString('a')]);
      expect(details, contains('SEARCH ta USING'));
      expect(details, contains('artist_key=?'));
      expect(details, contains('SEARCH t USING INTEGER PRIMARY KEY'));
    });

    test('the artist list walks track_artists in key order', () async {
      final details = await plan(artistCreditsSql);
      expect(details, contains('SCAN ta USING'));
    });

    test('Songs by title walk the title_sort index, no temp tree', () async {
      final details = await plan(songsSql(SongOrder.title));
      expect(details, contains('tracks_title_sort'));
      expect(details, isNot(contains('TEMP B-TREE')));
    });

    test('no browse query calls a custom function', () {
      for (final sql in [
        albumsSql,
        albumSql,
        artistAlbumsSql,
        artistCreditsSql,
        albumTracksSql,
        artistTracksSql,
        for (final order in SongOrder.values) songsSql(order),
      ]) {
        expect(sql, isNot(contains('kanaru_')));
      }
    });
  });
}
