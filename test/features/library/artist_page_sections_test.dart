import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_sql_functions.dart';
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

void main() {
  test('own albums, songs and appearances of an artist', () {
    final tracks = [
      track(
        'own',
        artist: 'Ann',
        album: 'Mine',
        albumArtist: 'Ann',
        year: 2001,
      ),
      track('older', artist: 'Ann', album: 'First', year: 1990),
      track('guest', artist: 'X; Ann', album: 'Theirs', albumArtist: 'X'),
      track('shared', artist: 'Ann; Bob', album: 'Duo'),
      track('loose', artist: 'Ann'),
    ];
    final page = ArtistPageSections.fromTracks('ann', tracks);

    expect(page.name, 'Ann');
    expect([for (final a in page.albums) a.title], ['First', 'Mine', 'Duo']);
    expect([for (final a in page.appearsOn) a.title], ['Theirs']);
    expect(page.songs, tracks);
    expect(page.albumCount, 4);
  });

  test('a second artist without album artist appears on the album', () {
    final tracks = [track('shared', artist: 'Ann; Bob', album: 'Duo')];
    final page = ArtistPageSections.fromTracks('bob', tracks);

    expect(page.name, 'Bob');
    expect(page.albums, isEmpty);
    expect([for (final a in page.appearsOn) a.title], ['Duo']);
  });

  test('tiles take the album artist, else the first artist, and max year', () {
    final page = ArtistPageSections.fromTracks('ann', [
      track('a', artist: 'Ann; Bob', album: 'Duo', year: 1999),
      track('b', artist: 'Ann', album: 'Duo', year: 2003),
    ]);
    final tile = page.albums.single;
    expect(tile.artist, 'Ann');
    expect(tile.year, 2003);
  });

  test('the name is the spelling at the matching position', () {
    final page = ArtistPageSections.fromTracks('anna', [
      track('t', artist: 'Ann; ANNA'),
    ]);
    expect(page.name, 'ANNA');
  });
}
