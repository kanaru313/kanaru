import '../../../core/database/artist_names.dart';
import '../../../core/database/library_database.dart';
import '../../../core/settings/library_sort.dart';
import '../albums/album_sort.dart';
import '../../../shared/artist_summaries.dart' show preferredSpelling;

/// The order of both album sections of an artist page: by year, unknown last,
/// then as the Albums tab breaks ties (title, then album key).
const artistAlbumsSort = SortChoice(AlbumSortField.year);

/// What an artist page lists:
/// - [albums]: albums the artist owns (one of its album artists, else its
///   first track artist; an album merged from several album artists is
///   owned by none),
/// - [songs]: every track crediting the artist, in the order of the album
///   tiles (the albums, then those appeared on), each album as the
///   query orders it (disc, track, title), tracks without an album last,
/// - [appearsOn]: the other albums holding those tracks.
///
/// Album details are the rows of the albums query, so a tile shows what the
/// Albums list shows; both sections order by [artistAlbumsSort].
class ArtistPageSections {
  const ArtistPageSections({
    required this.name,
    required this.albums,
    required this.songs,
    required this.appearsOn,
  });

  factory ArtistPageSections.fromTracks(
    String key,
    List<BrowseTrack> tracks,
    List<AlbumSummary> albumRows,
  ) {
    var owned = <AlbumSummary>[];
    var other = <AlbumSummary>[];
    for (final album in albumRows) {
      (_owners(album).contains(key) ? owned : other).add(album);
    }
    owned = sortAlbums(owned, artistAlbumsSort);
    other = sortAlbums(other, artistAlbumsSort);
    return ArtistPageSections(
      name: _displayName(key, tracks) ?? key,
      albums: owned,
      songs: _inTileOrder(tracks, [...owned, ...other]),
      appearsOn: other,
    );
  }

  /// The artists owning [album]: those of its key; without any (albums not
  /// told apart by artist) the artist shown on it, or nobody when several
  /// album artists are merged into it.
  static List<String> _owners(AlbumSummary album) {
    if (album.key.artistKeys.isNotEmpty) return album.key.artistKeys;
    return album.variousArtists ? const [] : artistKeys(album.artist);
  }

  /// The artist's name, chosen by [preferredSpelling] like in the list.
  final String name;
  final List<AlbumSummary> albums;
  final List<BrowseTrack> songs;
  final List<AlbumSummary> appearsOn;

  /// Albums on the page, both sections.
  int get albumCount => albums.length + appearsOn.length;

  /// The cover of the first album on the page that has one (its own albums
  /// before those it appears on), for the page's picture and colors.
  String? get coverKey =>
      [...albums, ...appearsOn].map((a) => a.coverKey).nonNulls.firstOrNull;

  /// Length of all [songs]; null when none has a known length.
  int? get durationMs {
    final known = songs.map((s) => s.durationMs).nonNulls;
    return known.isEmpty ? null : known.fold<int>(0, (a, b) => a + b);
  }
}

/// The preferred spelling of [key] among the tracks that credit it.
///
/// Independent of the artist split rules (which a person can change and
/// which the page does not know): a track's name comes from the default
/// split when that gives [key]; otherwise from the text of the tag itself,
/// at a place where a name spelled like [key] stands alone.
String? _displayName(String key, List<BrowseTrack> tracks) {
  String? best;
  for (final track in tracks) {
    final names = _namesOf(key, track.artist);
    for (final name in names) {
      best = preferredSpelling(best, name);
    }
  }
  return best;
}

/// The spellings of [key] in [tag]: from the default split, else every
/// stretch of the tag that has the key and is set off from letters and
/// digits around it. Nothing when the tag does not spell [key] that way.
Iterable<String> _namesOf(String key, String? tag) sync* {
  if (tag == null || tag.isEmpty) return;
  var found = false;
  for (final name in splitArtists(tag)) {
    if (artistKey(name) == key) {
      found = true;
      yield name;
    }
  }
  if (found || key.isEmpty) return;
  // Case folding that changes the length would shift the positions.
  final lower = tag.toLowerCase();
  if (lower.length != tag.length) return;
  for (var at = lower.indexOf(key); at >= 0; at = lower.indexOf(key, at + 1)) {
    final end = at + key.length;
    if (at > 0 && _letterOrDigit.hasMatch(tag[at - 1])) continue;
    if (end < tag.length && _letterOrDigit.hasMatch(tag[end])) continue;
    final candidate = tag.substring(at, end);
    if (candidate.trim() == candidate && artistKey(candidate) == key) {
      yield candidate;
    }
  }
}

final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// [tracks] (already ordered by album key, disc, track, title and id, as
/// the query returns them) grouped by the position of their album in
/// [albums]; tracks whose album is not in [albums], or that have none, go
/// last. One pass, each group keeps the query order.
List<BrowseTrack> _inTileOrder(
  List<BrowseTrack> tracks,
  List<AlbumSummary> albums,
) {
  final position = {for (final (i, a) in albums.indexed) a.key: i};
  final buckets = List.generate(albums.length + 1, (_) => <BrowseTrack>[]);
  for (final track in tracks) {
    buckets[position[track.albumKey] ?? albums.length].add(track);
  }
  return [for (final bucket in buckets) ...bucket];
}
