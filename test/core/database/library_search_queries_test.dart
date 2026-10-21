import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_search_queries.dart';
import 'package:kanaru/core/database/search_terms.dart';

import 'search_index_test_helpers.dart';

TracksCompanion _track(
  int rootId,
  String path,
  String title, {
  String? artist,
  String? album,
  String? albumArtist,
  String? genre,
}) => TracksCompanion.insert(
  rootId: rootId,
  path: path,
  mtimeMs: 1,
  sizeBytes: 10,
  title: title,
  artist: Value(artist),
  album: Value(album),
  albumArtist: Value(albumArtist),
  genre: Value(genre),
  addedAt: 100,
  updatedAt: 100,
);

void main() {
  late LibraryDatabase db;
  late int rootId;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() async {
    await expectSearchIndexIntact(db);
    await db.close();
  });

  Future<void> add(
    String title, {
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
  }) => db.upsertTracks([
    _track(
      rootId,
      '/m/${title.hashCode}-${artist.hashCode}.flac',
      title,
      artist: artist,
      album: album,
      albumArtist: albumArtist,
      genre: genre,
    ),
  ]);

  Future<List<String>> titles(String query, {int? limit}) async {
    final result = await db.searchSongs(
      searchTerms(query),
      limit: limit ?? searchSongLimit,
    );
    return [for (final s in result.songs) s.title];
  }

  test('son tung, SON TÙNG and so tu find Sơn Tùng', () async {
    await add('Lạc Trôi', artist: 'Sơn Tùng M-TP');
    await add('Other', artist: 'Someone');
    for (final query in ['son tung', 'SON TÙNG', 'Sơn Tùng', 'so tu', 'tung']) {
      expect(await titles(query), ['Lạc Trôi'], reason: query);
    }
  });

  test('dung lam finds Đừng Làm and di du dua di finds Đi Đu Đưa Đi', () async {
    await add('Đừng Làm Trái Tim Anh Đau');
    await add('Đi Đu Đưa Đi');
    expect(await titles('dung lam'), ['Đừng Làm Trái Tim Anh Đau']);
    expect(await titles('đừng làm'), ['Đừng Làm Trái Tim Anh Đau']);
    expect(await titles('di du dua di'), ['Đi Đu Đưa Đi']);
  });

  test('the beatles finds The Beatles', () async {
    await add('Help!', artist: 'The Beatles');
    expect(await titles('the beatles'), ['Help!']);
    expect(await titles('beat'), ['Help!']);
  });

  test('matches album, album artist and genre', () async {
    await add('One', album: 'Moonlight');
    await add('Two', albumArtist: 'Various Artists');
    await add('Three', genre: 'Drum and Bass');
    expect(await titles('moonl'), ['One']);
    expect(await titles('various'), ['Two']);
    expect(await titles('bass'), ['Three']);
  });

  test('every term must match', () async {
    await add('Blue Moon', artist: 'Ann');
    await add('Blue Sky', artist: 'Bob');
    expect(await titles('blue moon'), ['Blue Moon']);
    expect(await titles('blue ann'), ['Blue Moon']);
    expect(await titles('blue zebra'), isEmpty);
  });

  test('title matches rank above artist and genre matches', () async {
    await add('Plain', artist: 'Rock Band', genre: 'Rock');
    await add('Rock Anthem');
    await add('Zeta', genre: 'Rock');
    expect(await titles('rock'), ['Rock Anthem', 'Plain', 'Zeta']);
  });

  test('operators and quotes in the input never throw', () async {
    await add('Not Or And', artist: 'Near');
    for (final query in [
      '"',
      '""',
      '*',
      '-',
      ':',
      '(',
      ')',
      '^',
      'AND',
      'OR',
      'NOT',
      'NEAR',
      'NEAR(a b)',
      'a:b',
      '"x" AND y*',
      '-x',
      'a OR',
      '(((',
      "'; DROP TABLE tracks;--",
    ]) {
      await db.searchSongs(searchTerms(query));
    }
    expect(await titles('NOT or AND'), ['Not Or And']);
    expect(await titles('near "not"*'), ['Not Or And']);
  });

  test('counts every match and returns at most the limit', () async {
    for (var i = 0; i < 5; i++) {
      await add('Song $i', artist: 'Band');
    }
    final result = await db.searchSongs(searchTerms('band'), limit: 3);
    expect(result.songs, hasLength(3));
    expect(result.total, 5);
  });

  test('no terms returns nothing', () async {
    await add('Song');
    final result = await db.searchSongs(const []);
    expect(result.songs, isEmpty);
    expect(result.total, 0);
  });

  test('songs found agree with the name filter', () async {
    const names = [
      'Sơn Tùng M-TP',
      'AC/DC',
      'Đen Vâu',
      '1989',
      'B.o.B & Co.',
      '日本語の歌 2',
      'Private Use',
      'x\u{1F600}y z',
      'Beyoncé',
      'Beyoncé Knowles',
      'O’Connor',
      'Ünïcødé ß æ',
      'under_score-dash',
      'ＦＵＬＬ width',
    ];
    for (final name in names) {
      await add('~', artist: name); // a title with no words
    }
    final queries = {
      for (final name in names) ...[
        name,
        for (final t in searchTerms(name)) ...[
          t,
          t.substring(0, 1),
          if (t.runes.length > 2) String.fromCharCodes(t.runes.take(2)),
        ],
      ],
      'son b',
      'm tp',
      'co',
      'x y',
      'ac',
      'dc',
      'o connor',
      'full',
      'ss',
    };
    for (final query in queries) {
      final terms = searchTerms(query);
      if (terms.isEmpty) continue;
      final found = await db
          .customSelect(
            'SELECT artist FROM tracks WHERE id IN (SELECT rowid FROM '
            'track_search WHERE track_search MATCH ?1)',
            variables: [Variable.withString(ftsPrefixQuery(terms))],
          )
          .map((r) => r.read<String>('artist'))
          .get();
      final expected = [
        for (final name in names)
          if (termsMatch(searchTerms(name), terms)) name,
      ];
      expect(found..sort(), expected..sort(), reason: 'query "$query"');
    }
  });

  test('song search reads the full-text index', () async {
    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT rowid FROM track_search '
          "WHERE track_search MATCH '\"a\"*'",
        )
        .get();
    expect(
      plan.map((r) => r.read<String>('detail')).join(' '),
      contains('VIRTUAL TABLE INDEX'),
    );
  });

  group('a corrupt index', () {
    Future<void> corrupt() async {
      // Segment data overwritten with garbage: reading it fails with
      // SQLITE_CORRUPT_VTAB, as after a tokenizer change.
      await db.customStatement(
        'UPDATE track_search_data SET block = zeroblob(length(block)) '
        'WHERE id NOT IN (1, 10)',
      );
    }

    Future<void> seed() async {
      for (var i = 0; i < 30; i++) {
        await add('Song $i', artist: 'Band $i');
      }
    }

    test('is rebuilt once and the search is retried', () async {
      await seed();
      await corrupt();
      await expectLater(
        db
            .customSelect(
              'SELECT rowid FROM track_search WHERE track_search MATCH \'"song"*\'',
            )
            .get(),
        throwsA(anything),
        reason: 'the damage must be real for this test to mean anything',
      );
      final result = await db.searchSongs(searchTerms('song 1'));
      expect(result.total, 11);
      expect(result.songs.first.title, startsWith('Song 1'));
      expect(await titles('band 29'), ['Song 29']);
    });

    test('is not rebuilt again in the same session', () async {
      await seed();
      await corrupt();
      await db.searchSongs(searchTerms('song'));
      await corrupt();
      await expectLater(db.searchSongs(searchTerms('song')), throwsA(anything));
      // Leave the index sound for the teardown check.
      await db.customStatement(
        "INSERT INTO track_search(track_search) VALUES ('rebuild')",
      );
    });

    test(
      'is repaired when the error comes from the database isolate',
      () async {
        final dir = Directory.systemTemp.createTempSync(
          'kanaru_search_corrupt',
        );
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = LibraryDatabase(
          NativeDatabase.createInBackground(File('${dir.path}/library.db')),
        );
        final root = (await file.addRoots(['/m'], now: 1)).single;
        for (var i = 0; i < 30; i++) {
          await file.upsertTracks([_track(root, '/m/$i.flac', 'Song $i')]);
        }
        await file.customStatement(
          'UPDATE track_search_data SET block = zeroblob(length(block)) '
          'WHERE id NOT IN (1, 10)',
        );
        expect((await file.searchSongs(searchTerms('song 2'))).total, 11);
        await expectSearchIndexIntact(file);
        await file.close();
      },
    );
  });
}
