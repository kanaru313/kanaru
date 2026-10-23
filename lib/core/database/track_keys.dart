import 'artist_names.dart';
import 'library_browse_rows.dart' show albumArtistKeySeparator;
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
    this.artistSearch,
    this.albumSearch,
    this.albumArtistSearch,
    this.genreSearch,
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

  /// `sortKey` of the artist, album, album artist and genre tags, null with
  /// their tag; what the search index holds besides [titleSort]. Unlike
  /// [artistSort] they keep a leading "the".
  final String? artistSearch;
  final String? albumSearch;
  final String? albumArtistSearch;
  final String? genreSearch;

  /// The credited artists (the `artist` tag split into names) as
  /// (key, display name); keys are distinct.
  final List<({String key, String name})> artists;
}

/// Keys for a track with these tags. [artist], [albumArtist] and [genre] are
/// the raw tag strings (multiple values joined with "; "). The artists are
/// split by [artistRules]; the rows are stored with `keysVersionFor` of them.
TrackKeys trackKeysFor({
  required String title,
  String? artist,
  String? album,
  String? albumArtist,
  String? genre,
  SplitRules artistRules = defaultArtistRules,
}) {
  final names = splitArtists(artist, rules: artistRules);
  return TrackKeys(
    albumArtistKey: album == null
        ? null
        : albumArtistKey(albumArtist, artist, rules: artistRules),
    albumTitleKey: album == null ? null : albumTitleKey(album),
    albumDisplayArtist: albumArtist ?? names.firstOrNull,
    titleSort: sortKey(title),
    artistSort: artist == null ? null : artistSortKey(artist),
    albumSort: album == null ? null : artistSortKey(album),
    artistSearch: artist == null ? null : sortKey(artist),
    albumSearch: album == null ? null : sortKey(album),
    albumArtistSearch: albumArtist == null ? null : sortKey(albumArtist),
    genreSearch: genre == null ? null : sortKey(genre),
    artists: [for (final name in names) (key: artistKey(name), name: name)],
  );
}

/// Artist part of an album key: the keys of the album artists joined by
/// [albumArtistKeySeparator], else the key of the first track artist, else
/// `''`. Each artist key is whole; the joined string is not cut, so
/// `AlbumKey.artistKeys` gets every key back.
String albumArtistKey(
  String? albumArtist,
  String? artist, {
  SplitRules rules = defaultArtistRules,
}) {
  final owners = artistKeys(albumArtist, rules: rules);
  if (owners.isNotEmpty) return owners.join(albumArtistKeySeparator);
  return artistKeys(artist, rules: rules).firstOrNull ?? '';
}

/// Title part of an album key.
String albumTitleKey(String album) => groupKey(album);
