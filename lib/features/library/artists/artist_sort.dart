import '../../../core/settings/library_sort.dart';
import '../sort_compare.dart';
import 'artist_summaries.dart';

/// An artist with the name lower-cased once, not on every comparison.
typedef _Keyed = ({ArtistSummary artist, String name});

/// [artists] in the order of [sort]. Ties fall back to the name ascending
/// (ignoring case), then to the key.
List<ArtistSummary> sortArtists(
  List<ArtistSummary> artists,
  SortChoice<ArtistSortField> sort,
) {
  final keyed = <_Keyed>[
    for (final a in artists) (artist: a, name: a.name.toLowerCase()),
  ]..sort((a, b) => _compare(a, b, sort));
  return [for (final k in keyed) k.artist];
}

int _compare(_Keyed a, _Keyed b, SortChoice<ArtistSortField> sort) {
  final descending = sort.descending;
  final primary = switch (sort.field) {
    ArtistSortField.name => compareNullsLast(
      a.name,
      b.name,
      descending: descending,
    ),
    ArtistSortField.songCount => compareNullsLast(
      a.artist.songCount,
      b.artist.songCount,
      descending: descending,
    ),
    ArtistSortField.albumCount => compareNullsLast(
      a.artist.albumCount,
      b.artist.albumCount,
      descending: descending,
    ),
  };
  if (primary != 0) return primary;
  final name = a.name.compareTo(b.name);
  return name != 0 ? name : a.artist.key.compareTo(b.artist.key);
}
