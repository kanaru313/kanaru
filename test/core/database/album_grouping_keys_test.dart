import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/album_grouping_keys.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_keys_backfill.dart';
import 'package:kanaru/core/database/separator_rules.dart';
import 'package:kanaru/core/database/text_keys.dart';
import 'package:kanaru/core/database/track_keys.dart';
import 'package:kanaru/core/settings/library_scan_prefs.dart';

const _noArtist = AlbumGrouping(byAlbumArtist: false);
const _byYear = AlbumGrouping(byYear: true);
const _both = AlbumGrouping(byAlbumArtist: false, byYear: true);
const _custom = SplitRules(separators: ['|'], keepWhole: ['A|B']);

/// The version formula as it was before the grouping existed.
int _oldVersion(SplitRules rules) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode('$textKeysVersion|${rules.canonical}')) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return textKeysVersion + 1 + (hash & 0x3fffffff);
}

TracksCompanion _track(
  int n, {
  String album = 'Album',
  String? artist,
  String? albumArtist,
  int? year,
}) => TracksCompanion.insert(
  rootId: 1,
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
);

void main() {
  late LibraryDatabase db;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    await db.addRoots(['/m'], now: 1);
  });
  tearDown(() => db.close());

  group('keys version', () {
    test('the default grouping keeps today\'s version', () {
      expect(keysVersionFor(defaultArtistRules), textKeysVersion);
      expect(
        keysVersionFor(defaultArtistRules, const AlbumGrouping()),
        textKeysVersion,
      );
      expect(keysVersionFor(_custom), _oldVersion(_custom));
      expect(
        keysVersionFor(_custom, const AlbumGrouping()),
        _oldVersion(_custom),
      );
    });

    test('every other grouping has a version of its own', () {
      for (final rules in [defaultArtistRules, _custom]) {
        final versions = {
          keysVersionFor(rules),
          keysVersionFor(rules, _noArtist),
          keysVersionFor(rules, _byYear),
          keysVersionFor(rules, _both),
        };
        expect(versions, hasLength(4));
      }
      expect(
        keysVersionFor(defaultArtistRules, _byYear),
        isNot(textKeysVersion),
      );
    });
  });

  group('track keys', () {
    TrackKeys keys(
      AlbumGrouping g, {
      int? year = 1999,
      String? album = 'Abbey',
    }) => trackKeysFor(
      title: 't',
      artist: 'Ann',
      albumArtist: 'Bob',
      album: album,
      year: year,
      grouping: g,
    );

    test('the default grouping is the old key', () {
      final k = keys(const AlbumGrouping());
      expect(k.albumArtistKey, 'bob');
      expect(k.albumTitleKey, 'abbey');
      expect(albumTitleKey('Abbey'), 'abbey');
    });

    test('by year adds the year after U+001F, empty without one', () {
      expect(keys(_byYear).albumTitleKey, 'abbey\u001f1999');
      expect(keys(_byYear, year: null).albumTitleKey, 'abbey\u001f');
      expect(
        albumTitleKey('Abbey', year: 2000, byYear: true),
        'abbey\u001f2000',
      );
      expect(albumTitleKey('Abbey', year: 2000), 'abbey');
    });

    test('without the album artist the artist key is empty', () {
      expect(keys(_noArtist).albumArtistKey, '');
      expect(keys(_noArtist).albumTitleKey, 'abbey');
      expect(keys(_both).albumArtistKey, '');
      expect(keys(_both).albumTitleKey, 'abbey\u001f1999');
    });

    test('a track without an album has no album keys', () {
      final k = keys(_both, album: null);
      expect(k.albumArtistKey, isNull);
      expect(k.albumTitleKey, isNull);
    });
  });

  group('registry', () {
    test('defaults, is per database', () async {
      final other = LibraryDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      expect(albumGroupingFor(db), const AlbumGrouping());
      useAlbumGrouping(db, _both);
      expect(albumGroupingFor(db), _both);
      expect(albumGroupingFor(other), const AlbumGrouping());
    });

    test('a scan writes the grouped keys and version', () async {
      useAlbumGrouping(db, _both);
      await db.upsertTracks([
        _track(1, artist: 'Ann', albumArtist: 'Ann', year: 1999),
        _track(2, artist: 'Bob', albumArtist: 'Bob', year: 1999),
        _track(3, artist: 'Bob', albumArtist: 'Bob', year: 2001),
      ]);
      final rows = await db
          .customSelect(
            'SELECT album_artist_key AS a, album_title_key AS t, '
            'keys_version AS v FROM tracks ORDER BY id',
          )
          .get();
      expect([for (final r in rows) r.read<String>('a')], ['', '', '']);
      expect(
        [for (final r in rows) r.read<String>('t')],
        ['album\u001f1999', 'album\u001f1999', 'album\u001f2001'],
      );
      expect(
        rows.first.read<int>('v'),
        keysVersionFor(defaultArtistRules, _both),
      );

      final albums = await db.albums();
      expect(albums, hasLength(2));
      expect(albums.map((a) => a.trackCount).toList()..sort(), [1, 2]);
    });

    test(
      'without the album artist, albums of different artists merge',
      () async {
        await db.upsertTracks([
          _track(1, artist: 'Ann', albumArtist: 'Ann'),
          _track(2, artist: 'Bob', albumArtist: 'Bob'),
        ]);
        expect(await db.albums(), hasLength(2));

        useAlbumGrouping(db, _noArtist);
        expect(
          await countStaleKeys(
            db,
            keysVersionFor(defaultArtistRules, _noArtist),
          ),
          2,
        );
        await backfillLibraryKeys(db, grouping: _noArtist);
        final albums = await db.albums();
        expect(albums, hasLength(1));
        expect(albums.single.trackCount, 2);
        expect(albums.single.key.artistKey, '');
        expect(albums.single.key.artistKeys, isEmpty);
        expect(await db.albumTracks(albums.single.key), hasLength(2));
      },
    );
  });

  test(
    'the backfill leaves a row whose year changed since it read it',
    () async {
      await db.upsertTracks([_track(1, year: 1999)]);
      await backfillLibraryKeys(
        db,
        grouping: _byYear,
        afterRead: () => db.customStatement('UPDATE tracks SET year = 2005'),
      );
      var row = await db
          .customSelect(
            'SELECT album_title_key AS t, keys_version AS v FROM tracks',
          )
          .getSingle();
      expect(row.read<int>('v'), textKeysVersion);
      expect(row.read<String>('t'), 'album');

      expect(await backfillLibraryKeys(db, grouping: _byYear), 1);
      row = await db
          .customSelect(
            'SELECT album_title_key AS t, keys_version AS v FROM tracks',
          )
          .getSingle();
      expect(row.read<String>('t'), 'album\u001f2005');
      expect(row.read<int>('v'), keysVersionFor(defaultArtistRules, _byYear));
    },
  );

  test('a rescan without a year clears it and keys consistently', () async {
    useAlbumGrouping(db, _byYear);
    await db.upsertTracks([_track(1, year: 1999)]);
    await db.upsertTracks([
      TracksCompanion.insert(
        rootId: 1,
        path: '/m/1.flac',
        mtimeMs: 2,
        sizeBytes: 1,
        title: 'T1',
        album: const Value('Album'),
        addedAt: 1,
        updatedAt: 2,
      ),
    ]);
    final row = await db
        .customSelect('SELECT year, album_title_key AS t FROM tracks')
        .getSingle();
    expect(row.readNullable<int>('year'), isNull);
    expect(row.read<String>('t'), 'album\u001f');
  });
}
