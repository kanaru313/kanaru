import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/track_keys.dart';
import 'package:kanaru/features/library/artists/artist_page_sections.dart';

var _id = 0;

/// A row as the artist query returns it, keys made by the shared rules.
BrowseTrack track(
  String title, {
  required String artist,
  String? album,
  String? albumArtist,
  int? year,
}) {
  return BrowseTrack(
    id: _id++,
    path: '/$title',
    title: title,
    artist: artist,
    album: album,
    albumArtist: albumArtist,
    year: year,
    albumKey: album == null
        ? null
        : AlbumKey(albumArtistKey(albumArtist, artist), albumTitleKey(album)),
  );
}

AlbumSummary albumRow(
  String title, {
  required String artist,
  String? albumArtist,
  int? year,
  String? titleSort,
  bool noArtistInKey = false,
  bool variousArtists = false,
}) => AlbumSummary(
  key: AlbumKey(
    noArtistInKey ? '' : albumArtistKey(albumArtist, artist),
    albumTitleKey(title),
  ),
  title: title,
  artist: albumArtist ?? artist,
  year: year,
  trackCount: 1,
  addedAt: 1,
  titleSort: titleSort,
  variousArtists: variousArtists,
);

void main() {
  test('own albums, songs and appearances of an artist', () {
    final tracks = [
      track('own', artist: 'Ann', album: 'Mine', albumArtist: 'Ann'),
      track('guest', artist: 'X; Ann', album: 'Theirs', albumArtist: 'X'),
      track('loose', artist: 'Ann'),
    ];
    final page = ArtistPageSections.fromTracks('ann', tracks, [
      albumRow('Mine', artist: 'Ann', albumArtist: 'Ann', year: 2001),
      albumRow('First', artist: 'Ann', year: 1990),
      albumRow('Duo', artist: 'Ann'),
      albumRow('Theirs', artist: 'X; Ann', albumArtist: 'X'),
    ]);

    expect(page.name, 'Ann');
    expect([for (final a in page.albums) a.title], ['First', 'Mine', 'Duo']);
    expect([for (final a in page.appearsOn) a.title], ['Theirs']);
    expect(page.songs, tracks);
    expect(page.albumCount, 4);
  });

  test('a second artist without album artist appears on the album', () {
    final page = ArtistPageSections.fromTracks(
      'bob',
      [track('shared', artist: 'Ann; Bob', album: 'Duo')],
      [albumRow('Duo', artist: 'Ann; Bob')],
    );

    expect(page.name, 'Bob');
    expect(page.albums, isEmpty);
    expect([for (final a in page.appearsOn) a.title], ['Duo']);
  });

  test('tiles show the album row, not values derived from the tracks', () {
    final page = ArtistPageSections.fromTracks(
      'ann',
      [track('a', artist: 'Ann; Bob', album: 'Duo', year: 1999)],
      [albumRow('Duo', artist: 'Ann', year: 2003)],
    );
    final tile = page.albums.single;
    expect(tile.artist, 'Ann');
    expect(tile.year, 2003);
  });

  test('albums of one year sort by the title sort key, then by key', () {
    final page = ArtistPageSections.fromTracks('ann', const [], [
      albumRow('Zebra', artist: 'Ann', year: 2000),
      albumRow('Ánh', artist: 'Ann', year: 2000),
      albumRow('The Bee', artist: 'Ann', year: 2000),
      albumRow('Anh', artist: 'Ann', year: 2000),
      albumRow('Dated', artist: 'Ann', year: 1999),
      albumRow('Undated', artist: 'Ann'),
    ]);
    expect(
      [for (final a in page.albums) a.title],
      ['Dated', 'Anh', 'Ánh', 'The Bee', 'Zebra', 'Undated'],
    );
  });

  test('the name is the spelling at the matching position', () {
    final page = ArtistPageSections.fromTracks('anna', [
      track('t', artist: 'Ann; ANNA'),
    ], const []);
    expect(page.name, 'ANNA');
  });

  test('an owner with a cut key still owns the album', () {
    final long = 'n' * 300;
    final tracks = [
      track('t', artist: long, album: 'Big', albumArtist: '$long; B'),
    ];
    final rows = [albumRow('Big', artist: long, albumArtist: '$long; B')];
    final page = ArtistPageSections.fromTracks('n' * 256, tracks, rows);
    expect([for (final a in page.albums) a.title], ['Big']);
    final b = ArtistPageSections.fromTracks('b', tracks, rows);
    expect([for (final a in b.albums) a.title], ['Big']);
  });

  test('the name does not depend on the track order', () {
    final a = track('a', artist: 'ann');
    final b = track('b', artist: 'ANN');
    expect(ArtistPageSections.fromTracks('ann', [a, b], const []).name, 'ANN');
    expect(ArtistPageSections.fromTracks('ann', [b, a], const []).name, 'ANN');
  });

  test('songs follow the album tiles, with the whole album year', () {
    // The compilation holds a 1990 track of Ann but is a 2010 album: it
    // comes after the 2000 album, as its tile does.
    final comp = track(
      'comp-old',
      artist: 'Ann',
      album: 'Comp',
      albumArtist: 'Various',
      year: 1990,
    );
    final solo2 = track('solo-2', artist: 'Ann', album: 'Solo', year: 2000);
    final solo1 = track('solo-1', artist: 'Ann', album: 'Solo', year: 2000);
    final loose = track('loose', artist: 'Ann');
    final page = ArtistPageSections.fromTracks(
      'ann',
      [loose, solo1, solo2, comp],
      [
        albumRow('Comp', artist: 'Ann', albumArtist: 'Various', year: 2010),
        albumRow('Solo', artist: 'Ann', year: 2000),
      ],
    );

    expect([for (final a in page.albums) a.title], ['Solo']);
    expect([for (final a in page.appearsOn) a.title], ['Comp']);
    expect(
      [for (final t in page.songs) t.title],
      ['solo-1', 'solo-2', 'comp-old', 'loose'],
    );
  });

  test('songs of "Anh" and "Ánh" albums follow the tile order', () {
    final onAnh = track('on-anh', artist: 'Ann; Zed', album: 'Anh');
    final onAcute = track('on-ánh', artist: 'Ann; Zed', album: 'Ánh');
    final page = ArtistPageSections.fromTracks(
      'ann',
      [onAcute, onAnh],
      [
        albumRow('Ánh', artist: 'Ann; Zed'),
        albumRow('Anh', artist: 'Ann; Zed'),
      ],
    );
    final tiles = [for (final a in page.albums) a.title];
    expect(tiles, ['Anh', 'Ánh']);
    expect([for (final t in page.songs) t.title], ['on-anh', 'on-ánh']);
  });

  group('albums without an artist in the key', () {
    test('a single artist owns it', () {
      final page = ArtistPageSections.fromTracks(
        'ann',
        [track('s', artist: 'Ann', album: 'Mine')],
        [albumRow('Mine', artist: 'Ann', noArtistInKey: true)],
      );
      expect(page.albums.map((a) => a.title), ['Mine']);
      expect(page.appearsOn, isEmpty);
    });

    test('a merged album is under Appears on for each artist', () {
      for (final who in ['ann', 'bob']) {
        final page = ArtistPageSections.fromTracks(
          who,
          [track('s', artist: who == 'ann' ? 'Ann' : 'Bob', album: 'Mix')],
          [
            albumRow(
              'Mix',
              artist: 'Ann',
              noArtistInKey: true,
              variousArtists: true,
            ),
          ],
        );
        expect(page.albums, isEmpty);
        expect(page.appearsOn.map((a) => a.title), ['Mix']);
        expect(page.appearsOn.single.variousArtists, isTrue);
      }
    });

    test('a key with artists is unchanged by the flag', () {
      final page = ArtistPageSections.fromTracks(
        'ann',
        [track('s', artist: 'Ann', album: 'Mine', albumArtist: 'Ann')],
        [albumRow('Mine', artist: 'Ann', albumArtist: 'Ann')],
      );
      expect(page.albums.map((a) => a.title), ['Mine']);
    });
  });
}
