import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/app_destination.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/features/history/history_routes.dart' as history;
import 'package:kanaru/shared/library_route_keys.dart';

void main() {
  const odd = ['/ ? # % + = ü 漢 😀', '', 'a/b', '%2F', '..'];

  test('album keys round-trip any text', () {
    for (final artist in odd) {
      for (final title in odd) {
        final key = AlbumKey(artist, title);
        expect(decodeAlbumRouteKey(encodeAlbumRouteKey(key)), key);
      }
    }
  });

  test('artist keys round-trip any text', () {
    for (final name in odd) {
      expect(decodeArtistRouteKey(encodeArtistRouteKey(name)), name);
    }
  });

  test('genre keys round-trip any text', () {
    for (final name in odd) {
      expect(decodeGenreRouteKey(encodeGenreRouteKey(name)), name);
    }
    expect(decodeGenreRouteKey('!!'), isNull);
    expect(
      decodeGenreRouteKey(encodeAlbumRouteKey(const AlbumKey('a', 'b'))),
      isNull,
    );
  });

  test('language keys round-trip any text', () {
    for (final name in odd) {
      expect(decodeLanguageRouteKey(encodeLanguageRouteKey(name)), name);
    }
    expect(decodeLanguageRouteKey('!!'), isNull);
    expect(decodeLanguageRouteKey(''), isNull);
    expect(
      decodeLanguageRouteKey(encodeAlbumRouteKey(const AlbumKey('a', 'b'))),
      isNull,
    );
  });

  test('the unknown genre key is empty and still a valid route', () {
    expect(unknownGenreKey, isEmpty);
    final key = encodeGenreRouteKey(unknownGenreKey);
    expect(key, isNotEmpty);
    expect(decodeGenreRouteKey(key), unknownGenreKey);
    expect(genreLocation(unknownGenreKey), '/genres/$key');
  });

  test('folder keys round-trip any path', () {
    for (final path in [...odd, '/m/😀 dir/a b', '/日本/Ünï']) {
      expect(decodeFolderRouteKey(encodeFolderRouteKey(path)), path);
    }
    expect(decodeFolderRouteKey('!!'), isNull);
    expect(
      decodeFolderRouteKey(encodeAlbumRouteKey(const AlbumKey('a', 'b'))),
      isNull,
    );
  });

  test('the longest Linux path still opens', () {
    final path = '/${'😀' * 1000}';
    expect(path.codeUnits.length, lessThan(4096));
    final key = encodeFolderRouteKey(path);
    expect(key.length, lessThanOrEqualTo(8192));
    expect(decodeFolderRouteKey(key), path);
  });

  test('keys are URL-safe and never empty', () {
    for (final text in odd) {
      for (final key in [
        encodeArtistRouteKey(text),
        encodeGenreRouteKey(text),
        encodeFolderRouteKey(text),
        encodeAlbumRouteKey(AlbumKey(text, text)),
      ]) {
        expect(key, isNotEmpty);
        expect(key, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      }
    }
  });

  test('garbage decodes to null', () {
    final garbage = [
      '',
      '!!',
      'abc',
      'a',
      encodeArtistRouteKey('x'), // one part where an album needs two
      'eyJhIjoxfQ', // {"a":1}
      'WzEsMl0', // [1,2]
      'x' * 3000,
    ];
    for (final key in garbage) {
      expect(decodeAlbumRouteKey(key), isNull, reason: key);
    }
    expect(
      decodeArtistRouteKey(encodeAlbumRouteKey(const AlbumKey('a', 'b'))),
      isNull,
    );
    expect(decodeArtistRouteKey('!!'), isNull);
  });

  test('the largest keys the app makes still open', () {
    // Keys are cut to 256 characters; emoji and escaped control characters
    // are the longest in UTF-8 JSON.
    for (final char in ['😀', '漢', '\u0001']) {
      final key = AlbumKey(char * 256, char * 256);
      final encoded = encodeAlbumRouteKey(key);
      expect(decodeAlbumRouteKey(encoded), key, reason: '${encoded.length}');
    }
    final artist = '😀' * 256;
    expect(decodeArtistRouteKey(encodeArtistRouteKey(artist)), artist);
  });

  test('keys over 8192 characters are refused', () {
    final long = encodeArtistRouteKey('n' * 7000);
    expect(long.length, greaterThan(8192));
    expect(decodeArtistRouteKey(long), isNull);
  });

  test('locations use the shell paths', () {
    expect(albumsPath, AppDestination.albums.path);
    expect(artistsPath, AppDestination.artists.path);
    expect(genresPath, AppDestination.genres.path);
    expect(foldersPath, AppDestination.folders.path);
    expect(languagesPath, AppDestination.languages.path);
    expect(historyPath, AppDestination.history.path);
    expect(historyPath, history.historyPath);
    expect(
      languageLocation('vi'),
      '/languages/${encodeLanguageRouteKey('vi')}',
    );
    expect(folderLocation('/m/a'), '/folders/${encodeFolderRouteKey('/m/a')}');
    expect(genreLocation('rock'), '/genres/${encodeGenreRouteKey('rock')}');
    const key = AlbumKey('a', 'b');
    expect(albumLocation(key), '/albums/${encodeAlbumRouteKey(key)}');
    expect(
      artistAlbumLocation('a', key),
      '/artists/${encodeArtistRouteKey('a')}/album/${encodeAlbumRouteKey(key)}',
    );
  });
}
