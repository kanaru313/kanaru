import 'dart:convert';

import '../../core/database/library_database.dart' show AlbumKey;

/// Paths of the Albums and Artists branches. Kept here because features do
/// not import `app/`; a test checks them against the shell destinations.
const albumsPath = '/albums';
const artistsPath = '/artists';

/// Longest route key accepted: keys are cut to 256 characters in SQL, so a
/// longer one was not made by this app.
const _maxRouteKeyLength = 2048;

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

/// An album page in the Albums branch.
String albumLocation(AlbumKey key) => '$albumsPath/${encodeAlbumRouteKey(key)}';

/// An artist page; [artistKey] is a lower-cased name from SQL.
String artistLocation(String artistKey) =>
    '$artistsPath/${encodeArtistRouteKey(artistKey)}';

/// An album opened from an artist page, staying in the Artists branch.
String artistAlbumLocation(String artistKey, AlbumKey albumKey) =>
    '${artistLocation(artistKey)}/album/${encodeAlbumRouteKey(albumKey)}';
