/// Joins the artist keys in [AlbumKey.artistKey]. Never inside a key: `;`
/// always separates artist names.
const albumArtistKeySeparator = '; ';

/// Identifies an album while there is no albums table: the keys of its album
/// artists (else of the first track artist) and its lower-cased title, made
/// by the rules in `artist_names.dart`, each key cut to 256 characters.
class AlbumKey {
  const AlbumKey(this.artistKey, this.titleKey);

  /// The keys of its album artists joined by [albumArtistKeySeparator], or
  /// of its first track artist. Empty when the album has neither.
  final String artistKey;
  final String titleKey;

  /// The artist keys in [artistKey]: the artists who own the album.
  List<String> get artistKeys =>
      artistKey.isEmpty ? const [] : artistKey.split(albumArtistKeySeparator);

  @override
  bool operator ==(Object other) =>
      other is AlbumKey &&
      other.artistKey == artistKey &&
      other.titleKey == titleKey;

  @override
  int get hashCode => Object.hash(artistKey, titleKey);

  @override
  String toString() => 'AlbumKey($artistKey, $titleKey)';
}

/// One album grouped from its tracks.
class AlbumSummary {
  const AlbumSummary({
    required this.key,
    required this.title,
    required this.trackCount,
    required this.addedAt,
    this.artist,
    this.year,
    this.durationMs,
    this.coverKey,
  });

  final AlbumKey key;

  /// One spelling of the title among its tracks (the smallest).
  final String title;

  /// The album artist, else the first track artist; null when neither is set.
  final String? artist;

  /// The latest year among its tracks.
  final int? year;
  final int trackCount;

  /// Sum of the known track durations; null when none is known.
  final int? durationMs;

  /// When its most recently added track was indexed.
  final int addedAt;

  /// The smallest cover key among its tracks, so the choice is stable; null
  /// when none of its tracks has a cover.
  final String? coverKey;
}

/// The tracks that share one exact `artist` value: the value, how many
/// tracks carry it and which albums they belong to (tracks without an album
/// add no key).
class ArtistCredit {
  const ArtistCredit({
    required this.artist,
    required this.trackCount,
    required this.albumKeys,
  });

  /// Possibly several artists; see `splitArtists`.
  final String artist;
  final int trackCount;
  final Set<AlbumKey> albumKeys;
}

/// A track row for the album and artist pages.
class BrowseTrack {
  const BrowseTrack({
    required this.id,
    required this.path,
    required this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.year,
    this.discNo,
    this.trackNo,
    this.durationMs,
    this.albumKey,
    this.coverKey,
  });

  final int id;
  final String path;
  final String title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? year;
  final int? discNo;
  final int? trackNo;
  final int? durationMs;

  /// The key of its album; null when it has no album.
  final AlbumKey? albumKey;

  /// Cover thumbnail key in the cover cache; null when there is no cover.
  final String? coverKey;
}

/// What the Songs list can be ordered by.
enum SongOrder { title, artist, album, year, dateAdded, duration }
