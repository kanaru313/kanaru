import 'dart:convert';

import '../core/database/library_database.dart' show AlbumKey;

/// Paths of the Albums, Artists, Genres and Folders branches. Kept here because
/// `shared/` and features do not import `app/`; a test checks them against
/// the shell destinations.
const albumsPath = '/albums';
const artistsPath = '/artists';
const genresPath = '/genres';
const languagesPath = '/languages';
const foldersPath = '/folders';

/// Same text as `historyPath` in `features/history/history_routes.dart`,
/// repeated for features that may not import each other; a test keeps them
/// equal.
const historyPath = '/history';

/// Longest route key accepted. Each key part holds at most 256 characters
/// (an album artist key may join several), and the worst characters (4-byte
/// UTF-8, or control characters JSON escapes as 6 bytes) grow 4/3 in base64:
/// 256 + 256 emoji give about 2 740 characters. 8192 leaves room for a few
/// album artists while still refusing absurd input.
const _maxRouteKeyLength = 8192;

/// `base64Url(utf8(json([...parts])))` without padding: no `/ ? # % =`,
/// never empty, decoded once by go_router and kept intact in the history.
String _encode(List<String> parts) =>
    base64Url.encode(utf8.encode(jsonEncode(parts))).replaceAll('=', '');

/// The [length] strings in [key], or `null` when it is not a key made by
/// [_encode].
List<String>? _decode(String key, int length) {
  if (key.isEmpty || key.length > _maxRouteKeyLength) return null;
  try {
    final padded = key.padRight((key.length + 3) ~/ 4 * 4, '=');
    final json = jsonDecode(utf8.decode(base64Url.decode(padded)));
    if (json is! List || json.length != length) return null;
    if (json.any((part) => part is! String)) return null;
    return json.cast<String>();
  } on FormatException {
    return null;
  }
}

String encodeAlbumRouteKey(AlbumKey key) =>
    _encode([key.artistKey, key.titleKey]);

AlbumKey? decodeAlbumRouteKey(String routeKey) {
  final parts = _decode(routeKey, 2);
  return parts == null ? null : AlbumKey(parts[0], parts[1]);
}

String encodeArtistRouteKey(String artistKey) => _encode([artistKey]);

String? decodeArtistRouteKey(String routeKey) => _decode(routeKey, 1)?.single;

/// The key of the genre page for tracks with no usable genre (no tag, or one
/// with nothing but blanks and separators). Never a real [genreKey]: that is
/// never empty, because `splitGenres` drops names whose key is empty. Encoded
/// like any key, so `genreLocation(unknownGenreKey)` is a valid route.
const unknownGenreKey = '';

String encodeGenreRouteKey(String genreKey) => _encode([genreKey]);

String? decodeGenreRouteKey(String routeKey) => _decode(routeKey, 1)?.single;

String encodeLanguageRouteKey(String languageKey) => _encode([languageKey]);

String? decodeLanguageRouteKey(String routeKey) => _decode(routeKey, 1)?.single;

String encodeFolderRouteKey(String path) => _encode([path]);

String? decodeFolderRouteKey(String routeKey) => _decode(routeKey, 1)?.single;

/// An album page in the Albums branch.
String albumLocation(AlbumKey key) => '$albumsPath/${encodeAlbumRouteKey(key)}';

/// An artist page; [artistKey] comes from `artistKey` in `artist_names.dart`.
String artistLocation(String artistKey) =>
    '$artistsPath/${encodeArtistRouteKey(artistKey)}';

/// An album opened from an artist page, staying in the Artists branch.
String artistAlbumLocation(String artistKey, AlbumKey albumKey) =>
    '${artistLocation(artistKey)}/album/${encodeAlbumRouteKey(albumKey)}';

/// A genre page; [genreKey] comes from `genreKey` in `genre_names.dart`.
String genreLocation(String genreKey) =>
    '$genresPath/${encodeGenreRouteKey(genreKey)}';

/// A language page; [languageKey] is the normalized language code or name.
String languageLocation(String languageKey) =>
    '$languagesPath/${encodeLanguageRouteKey(languageKey)}';

/// A folder page; [path] is the absolute path without a trailing `/`.
String folderLocation(String path) =>
    '$foldersPath/${encodeFolderRouteKey(path)}';
