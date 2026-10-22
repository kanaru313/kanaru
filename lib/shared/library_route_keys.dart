import 'dart:convert';

import '../core/database/library_database.dart' show AlbumKey;

/// Paths of the Albums, Artists and Genres branches. Kept here because
/// `shared/` and features do not import `app/`; a test checks them against
/// the shell destinations.
const albumsPath = '/albums';
const artistsPath = '/artists';
const genresPath = '/genres';

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

String encodeGenreRouteKey(String genreKey) => _encode([genreKey]);

String? decodeGenreRouteKey(String routeKey) => _decode(routeKey, 1)?.single;

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
