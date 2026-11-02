import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/album_grouping_keys.dart';
import 'package:kanaru/core/database/album_links_provider.dart';
import 'package:kanaru/core/database/library_browse_album_links.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_keys_provider.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/settings/library_scan_prefs.dart';

void main() {
  late LibraryDatabase db;
  late int rootId;
  var next = 0;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  Future<void> store({
    String? artist,
    String? album = 'Al',
    String? albumArtist,
    String? path,
  }) async {
    final n = next++;
    await db.upsertTracks([
      TracksCompanion.insert(
        rootId: rootId,
        path: path ?? '/m/$n.flac',
        mtimeMs: 1,
        sizeBytes: 1,
        title: 'T$n',
        artist: Value(artist),
        album: Value(album),
        albumArtist: Value(albumArtist),
        addedAt: 1,
        updatedAt: 1,
      ),
    ]);
  }

  /// The key of the only album, or of the one titled [title].
  Future<AlbumKey> keyOf([String title = 'Al']) async {
    final all = await db.albums();
    return all.firstWhere((a) => a.title == title).key;
  }

  Future<List<String>> names(AlbumKey key) async => [
    for (final a in (await db.albumLinks(key))!.artists) a.name,
  ];

  group('artists', () {
    test('the album artist wins over guests', () async {
      await store(artist: 'Da LAB; Guest', albumArtist: 'Da LAB');
      await store(artist: 'Da LAB feat. Other', albumArtist: 'Da LAB');
      expect(await names(await keyOf()), ['Da LAB']);
    });

    test('several album artists keep the tag order', () async {
      await store(artist: 'Wxrdie; Da LAB', albumArtist: 'Da LAB; Wxrdie');
      expect(await names(await keyOf()), ['Da LAB', 'Wxrdie']);
    });

    test(
      'an album artist nobody credits falls back to track artists',
      () async {
        await store(artist: 'Ann', albumArtist: 'Various Artists');
        await store(artist: 'Bob', albumArtist: 'Various Artists');
        await store(artist: 'Bob', albumArtist: 'Various Artists');
        expect(await names(await keyOf()), ['Bob', 'Ann']);
      },
    );

    test('no album artist gives the track artists', () async {
      await store(artist: 'Ann');
      await store(artist: 'Ann; Bob');
      expect(await names(await keyOf()), ['Ann', 'Bob']);
    });

    test('a merged album lists the album artists with pages', () async {
      useAlbumGrouping(db, const AlbumGrouping(byAlbumArtist: false));
      await store(artist: 'Ann', albumArtist: 'Ann');
      await store(artist: 'Bob', albumArtist: 'Bob');
      await store(artist: 'Cy', albumArtist: 'Ghost');
      final key = await keyOf();
      expect((await db.album(key))!.variousArtists, isTrue);
      expect(await names(key), ['Ann', 'Bob']);
    });

    test('a literal Unknown Artist is a normal artist', () async {
      await store(artist: 'Unknown Artist');
      expect(await names(await keyOf()), ['Unknown Artist']);
    });

    test('equal counts keep the order credits were written', () async {
      await store(artist: 'Zed; Ann');
      expect(await names(await keyOf()), ['Zed', 'Ann']);
    });

    test('an uncredited album artist is left out', () async {
      await store(artist: 'Da LAB', albumArtist: 'Da LAB; Ghost');
      expect(await names(await keyOf()), ['Da LAB']);
    });

    test('an album artist credited only on another album is ignored', () async {
      await store(artist: 'Ann', albumArtist: 'Bob');
      await store(artist: 'Bob', album: 'Other');
      expect(await names(await keyOf()), ['Ann']);
    });

    test('a credit elsewhere does not hide the compilation artists', () async {
      await store(artist: 'Ann', albumArtist: 'Various Artists');
      await store(artist: 'Bob', albumArtist: 'Various Artists');
      await store(artist: 'Various Artists', album: 'Other');
      expect(await names(await keyOf()), ['Ann', 'Bob']);
    });

    test('one album artist spelled two ways is one entry', () async {
      await store(artist: 'Da LAB', albumArtist: 'Da LAB');
      await store(artist: 'da lab', albumArtist: 'da lab');
      expect(await names(await keyOf()), ['Da LAB']);
    });

    test('no artist tags give no artists', () async {
      await store();
      expect(await names(await keyOf()), isEmpty);
    });
  });

  group('folders', () {
    test('one folder', () async {
      await store(path: '/m/a/1.flac');
      await store(path: '/m/a/2.flac');
      final folders = (await db.albumLinks(await keyOf()))!.folders;
      expect(folders, [
        const AlbumFolder(
          path: '/m/a',
          songCount: 2,
          samplePath: '/m/a/1.flac',
        ),
      ]);
    });

    test('sorted by count then path, sample is the smallest path', () async {
      for (final p in [
        '/m/z/2.flac',
        '/m/z/1.flac',
        '/m/b/1.flac',
        '/m/a/1.flac',
        '/m/c/1.flac',
        '/m/c/0.flac',
        '/m/c/9.flac',
      ]) {
        await store(path: p);
      }
      final folders = (await db.albumLinks(await keyOf()))!.folders;
      expect(
        [for (final f in folders) (f.path, f.songCount)],
        [('/m/c', 3), ('/m/z', 2), ('/m/a', 1), ('/m/b', 1)],
      );
      expect(folders.first.samplePath, '/m/c/0.flac');
    });

    test('albumFoldersOf edge cases', () {
      expect(albumFoldersOf(const []), isEmpty);
      expect(albumFoldersOf(['a.flac']), isEmpty);
      expect(albumFoldersOf(['/a.flac']), [
        const AlbumFolder(path: '/', songCount: 1, samplePath: '/a.flac'),
      ]);
    });

    test('albumFoldersOf skips non-local paths', () {
      expect(albumFoldersOf(['http://h/a/1.mp3', '/m/a/1.flac']), [
        const AlbumFolder(
          path: '/m/a',
          songCount: 1,
          samplePath: '/m/a/1.flac',
        ),
      ]);
    });
  });

  test('summary comes with the links', () async {
    await store(artist: 'Ann');
    await store(artist: 'Ann');
    expect((await db.albumLinks(await keyOf()))!.summary.trackCount, 2);
  });

  test('an album whose tracks were removed gives null', () async {
    await store(artist: 'Ann');
    final key = await keyOf();
    final ids = await db.select(db.tracks).map((t) => t.id).get();
    await db.deleteTracksById(ids);
    expect(await db.albumLinks(key), isNull);
  });

  group('provider', () {
    test('no library gives null', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(
        await c.read(albumModalLinksProvider(const AlbumKey('a', 'b')).future),
        isNull,
      );
    });

    test('a failing read is not retried', () async {
      final broken = LibraryDatabase(NativeDatabase.memory());
      await broken.customStatement('PRAGMA foreign_keys = OFF');
      await broken.customStatement('DROP TABLE tracks');
      final c = ProviderContainer(
        overrides: [
          libraryDatabaseProvider.overrideWithValue(broken),
          keysReadyProvider.overrideWithValue(true),
        ],
      );
      addTearDown(c.dispose);
      final provider = albumModalLinksProvider(const AlbumKey('a', 'b'));
      final sub = c.listen(provider, (_, _) {});
      await expectLater(
        c.read(provider.future).timeout(const Duration(seconds: 1)),
        throwsA(isNot(isA<TimeoutException>())),
      );
      expect(c.read(provider).hasError, isTrue);
      sub.close();
    });
  });

  test('album key queries use tracks_album_key', () async {
    for (final (sql, extra) in [
      (albumArtistNamesSql, 0),
      (albumTrackArtistsSql, 0),
      (albumPathsSql, 0),
      (albumCreditedKeysSql(2), 2), // starts from the artist key index
    ]) {
      final rows = await db
          .customSelect(
            'EXPLAIN QUERY PLAN $sql',
            variables: [for (var i = 0; i < 2 + extra; i++) Variable('k$i')],
          )
          .get();
      final plan = rows.map((r) => r.read<String>('detail')).join('\n');
      expect(
        plan,
        contains(extra == 0 ? 'tracks_album_key' : 'track_artists_1'),
        reason: sql,
      );
      expect(plan, isNot(matches(RegExp(r'SCAN (tracks|t)\b'))), reason: sql);
    }
  });
}
