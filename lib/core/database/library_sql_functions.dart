import 'package:sqlite3/sqlite3.dart';

import 'artist_names.dart';
import 'library_browse_rows.dart';
import 'text_keys.dart';

/// Separates artist keys in [artistKeysSql] results; never inside a key, as
/// `;` always splits names.
const artistKeysDelimiter = ';';

/// Makes the artist rules of `artist_names.dart` callable from SQL on
/// [rawDb], so SQL and Dart compute the same keys. Runs once per connection
/// (with the other connection setup).
///
/// - `kanaru_artist_keys(artist)`: `;k1;k2;`, the keys of every artist, for
///   `instr(…, ';' || ?key || ';') > 0`; NULL when there is none.
/// - `kanaru_first_artist(artist)`: the first artist name; NULL if none.
/// - `kanaru_album_artist_key(album_artist, artist)`: album key, artist
///   part: the keys of the album artists joined by
///   [albumArtistKeySeparator], else the key of the first track artist,
///   else `''`.
/// - `kanaru_album_title_key(album)`: album key, title part (lower case,
///   cut like artist keys); NULL for NULL.
void registerLibrarySqlFunctions(Database rawDb) {
  void scalar(String name, int args, Object? Function(List<Object?>) body) =>
      rawDb.createFunction(
        functionName: name,
        argumentCount: AllowedArgumentCount(args),
        deterministic: true,
        function: body,
      );

  scalar('kanaru_artist_keys', 1, (args) {
    final artist = args[0];
    return artist is String ? _cached(_keysCache, artist, _joinedKeys) : null;
  });
  scalar('kanaru_first_artist', 1, (args) {
    final artist = args[0];
    return artist is String
        ? _cached(_firstCache, artist, (a) => splitArtists(a).firstOrNull)
        : null;
  });
  scalar('kanaru_album_artist_key', 2, (args) {
    final albumArtist = args[0] as String?;
    final artist = args[1] as String?;
    return _cached(
      _albumArtistCache,
      '${albumArtist ?? ''}\u0000${artist ?? ''}',
      (_) => albumArtistKey(albumArtist, artist),
    );
  });
  scalar('kanaru_album_title_key', 1, (args) {
    final album = args[0];
    return album is String ? albumTitleKey(album) : null;
  });
}

/// Artist part of an album key; see [registerLibrarySqlFunctions]. Each
/// artist key is already cut; the joined string is not, so
/// [AlbumKey.artistKeys] gets every key back whole.
String albumArtistKey(String? albumArtist, String? artist) {
  final owners = artistKeys(albumArtist);
  if (owners.isNotEmpty) return owners.join(albumArtistKeySeparator);
  return artistKeys(artist).firstOrNull ?? '';
}

/// Title part of an album key.
String albumTitleKey(String album) => groupKey(album);

// Tags repeat across the tracks of an album and an artist, so results are
// cached by input. A cache is cleared when large, which keeps memory bounded
// without bookkeeping.
const _cacheLimit = 100000;
final _keysCache = <String, String?>{};
final _firstCache = <String, String?>{};
final _albumArtistCache = <String, String>{};

T _cached<T>(Map<String, T> cache, String input, T Function(String) compute) {
  final hit = cache[input];
  if (hit != null || cache.containsKey(input)) return hit as T;
  if (cache.length >= _cacheLimit) cache.clear();
  return cache[input] = compute(input);
}

String? _joinedKeys(String artist) {
  final keys = artistKeys(artist);
  return keys.isEmpty
      ? null
      : '$artistKeysDelimiter${keys.join(artistKeysDelimiter)}'
            '$artistKeysDelimiter';
}
