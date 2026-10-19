/// Identifies an album while there is no albums table: the lower-cased album
/// artist (else the first track artist) and the lower-cased album title, both
/// computed in SQL and cut to 256 characters.
class AlbumKey {
  const AlbumKey(this.artistKey, this.titleKey);

  /// Empty when the album has neither an album artist nor a track artist.
  final String artistKey;
  final String titleKey;

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
}

/// The tracks that share one exact `artist` value: the value as shown, its
/// lower-cased form from SQL, how many tracks carry it and which albums they
/// belong to (tracks without an album add no key).
class ArtistCredit {
  const ArtistCredit({
    required this.artist,
    required this.artistKey,
    required this.trackCount,
    required this.albumKeys,
  });

  /// Joined with `"; "` when the track has several artists.
  final String artist;
  final String artistKey;
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
    this.artistKeys,
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

  /// [artist] lower-cased in SQL, so its parts match the artist keys.
  final String? artistKeys;
}

/// What the Songs list can be ordered by.
enum SongOrder { title, artist, album, year, dateAdded, duration }
