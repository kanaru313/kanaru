import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/artist_cover_queries.dart';
import 'package:kanaru/core/database/library_database.dart';

late int _rootId;
var _next = 0;

TracksCompanion row({
  String? artist,
  String? album,
  String? albumArtist,
  int? year,
  String? coverKey,
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
    year: Value(year),
    addedAt: 1,
    updatedAt: 1,
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

  test('the earliest album with a cover gives the artist cover', () async {
    await db.upsertTracks([
      row(artist: 'Ann', album: 'Late', year: 2010, coverKey: 'late'),
      row(artist: 'Ann', album: 'No Art', year: 1990),
      row(artist: 'Ann', album: 'Early', year: 2000, coverKey: 'early2'),
      row(artist: 'Ann', album: 'Early', year: 1995, coverKey: 'early1'),
      row(artist: 'Ann', album: 'Undated', coverKey: 'undated'),
    ]);
    // The album's latest year (2000) still comes before 2010; its smallest
    // cover key is the album cover.
    expect(await db.artistCovers(), {'ann': 'early1'});
  });

  test('same year: by title sort key, without a leading "the"', () async {
    await db.upsertTracks([
      row(artist: 'Ann', album: 'The Zoo', year: 2000, coverKey: 'zoo'),
      row(artist: 'Ann', album: 'Moon', year: 2000, coverKey: 'moon'),
    ]);
    expect(await db.artistCovers(), {'ann': 'moon'});
  });

  test('owned albums come before albums appeared on', () async {
    await db.upsertTracks([
      row(artist: 'Bob; Ann', album: 'Guest', year: 1990, coverKey: 'guest'),
      row(artist: 'Ann', album: 'Own', year: 2020, coverKey: 'own'),
      row(
        artist: 'Ann',
        album: 'Duo',
        albumArtist: 'Cy; Ann',
        year: 2021,
        coverKey: 'duo',
      ),
    ]);
    final covers = await db.artistCovers();
    expect(covers['ann'], 'own');
    expect(covers['bob'], 'guest');
    expect(covers['cy'], isNull, reason: 'Cy credits no track');
  });

  test('an artist with only appearances uses the first of them', () async {
    await db.upsertTracks([
      row(artist: 'Bob; Ann', album: 'B', year: 2005, coverKey: 'b'),
      row(artist: 'Cy; Ann', album: 'C', year: 2001, coverKey: 'c'),
    ]);
    expect((await db.artistCovers())['ann'], 'c');
  });

  test('artists without any album cover are missing', () async {
    await db.upsertTracks([
      row(artist: 'Ann', album: 'X'),
      row(artist: 'Bob', coverKey: 'single'),
    ]);
    expect(await db.artistCovers(), isEmpty);
  });
}
