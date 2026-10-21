import '../../../core/database/text_keys.dart';
import '../../../core/settings/library_sort.dart';
import '../../../shared/sort_compare.dart';
import '../../../shared/artist_summaries.dart';

/// An artist with the sort key of the name made once, not on every comparison.
typedef _Keyed = ({ArtistSummary artist, String name});

/// [artists] in the order of [sort]. Ties fall back to the name ascending
/// (by `artistSortKey`: ignoring case, accents and a leading "The"), then to
/// the key.
List<ArtistSummary> sortArtists(
  List<ArtistSummary> artists,
  SortChoice<ArtistSortField> sort,
) {
  final keyed = <_Keyed>[
    for (final a in artists) (artist: a, name: artistSortKey(a.name)),
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
  final name = compareCodePoints(a.name, b.name);
  return name != 0 ? name : compareCodePoints(a.artist.key, b.artist.key);
}
