import 'artist_names.dart';
import 'library_sql_functions.dart' show albumArtistKey, albumTitleKey;
import 'text_keys.dart';

/// The stored keys of one track, derived from its tags. The only place that
/// decides them: the scan writes them and the background backfill rewrites
/// them with the same function.
class TrackKeys {
  const TrackKeys({
    required this.titleSort,
    required this.artists,
    this.albumArtistKey,
    this.albumTitleKey,
    this.albumDisplayArtist,
    this.artistSort,
    this.albumSort,
  });

  /// Artist and title parts of the album key; null when the track has no
  /// album.
  final String? albumArtistKey;
  final String? albumTitleKey;

  /// The album artist tag, else the first track artist.
  final String? albumDisplayArtist;

  final String titleSort;
  final String? artistSort;
  final String? albumSort;

  /// The credited artists (the `artist` tag split into names) as
  /// (key, display name); keys are distinct.
  final List<({String key, String name})> artists;
}

/// Keys for a track with these tags. [artist] and [albumArtist] are the raw
/// tag strings (multiple values joined with "; ").
TrackKeys trackKeysFor({
  required String title,
  String? artist,
  String? album,
  String? albumArtist,
}) {
  final names = splitArtists(artist);
  return TrackKeys(
    albumArtistKey: album == null ? null : albumArtistKey(albumArtist, artist),
    albumTitleKey: album == null ? null : albumTitleKey(album),
    albumDisplayArtist: albumArtist ?? names.firstOrNull,
    titleSort: sortKey(title),
    artistSort: artist == null ? null : artistSortKey(artist),
    albumSort: album == null ? null : artistSortKey(album),
    artists: [for (final name in names) (key: artistKey(name), name: name)],
  );
}
