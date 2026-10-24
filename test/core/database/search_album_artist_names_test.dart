import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/album_grouping_keys.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/search_album_artist_names.dart';
import 'package:kanaru/core/database/search_name_index.dart';
import 'package:kanaru/core/database/search_terms.dart';
import 'package:kanaru/core/settings/library_scan_prefs.dart';

void main() {
  late LibraryDatabase db;
  late int rootId;
  var next = 0;

  TracksCompanion track(String album, String albumArtist) {
    final n = next++;
    return TracksCompanion.insert(
      rootId: rootId,
      path: '/m/$n.flac',
      mtimeMs: 1,
      sizeBytes: 1,
      title: 'T$n',
      artist: Value(albumArtist),
      album: Value(album),
      albumArtist: Value(albumArtist),
      addedAt: 1,
      updatedAt: 1,
    );
  }

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
    useAlbumGrouping(db, const AlbumGrouping(byAlbumArtist: false));
  });
  tearDown(() => db.close());

  test('a merged album lists all its artists, sorted', () async {
    await db.upsertTracks([
      track('Hits', 'Queen'),
      track('Hits', 'ABBA'),
      track('Hits', 'Madonna'),
      track('Hits', 'Queen'),
      track('Solo', 'Queen'),
    ]);
    final names = await db.mergedAlbumArtistNames();
    expect(names, {
      const AlbumKey('', 'hits'): ['ABBA', 'Madonna', 'Queen'],
    });
  });

  test('no albums, or one artist each: nothing', () async {
    expect(await db.mergedAlbumArtistNames(), isEmpty);
    await db.upsertTracks([track('Solo', 'Queen'), track('Solo', 'Queen')]);
    expect(await db.mergedAlbumArtistNames(), isEmpty);
  });

  test('the album is found by the artist that sorts in the middle', () async {
    await db.upsertTracks([
      track('Hits', 'Queen'),
      track('Hits', 'ABBA'),
      track('Hits', 'Madonna'),
      track('Other', 'Zed'),
    ]);
    final albums = await db.albums();
    final index = albumSearchIndex(
      albums,
      artistNames: await db.mergedAlbumArtistNames(),
    );
    for (final q in ['madonna', 'queen', 'abba', 'hits']) {
      expect([for (final a in index.match(searchTerms(q))) a.title], ['Hits']);
    }
    // Shown artist is unchanged.
    expect(albums.firstWhere((a) => a.title == 'Hits').artist, 'ABBA');
  });
}
