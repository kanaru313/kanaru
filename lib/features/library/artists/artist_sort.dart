import '../../../core/settings/library_sort.dart';
import '../sort_compare.dart';
import 'artist_summaries.dart';

/// [artists] in the order of [sort]. Ties fall back to the name ascending,
/// then to the key.
List<ArtistSummary> sortArtists(
  List<ArtistSummary> artists,
  SortChoice<ArtistSortField> sort,
) => [...artists]..sort((a, b) => compareArtists(a, b, sort));

int compareArtists(
  ArtistSummary a,
  ArtistSummary b,
  SortChoice<ArtistSortField> sort,
) {
  final descending = sort.descending;
  final primary = switch (sort.field) {
    ArtistSortField.name => compareText(a.name, b.name, descending: descending),
    ArtistSortField.songCount => compareNullsLast(
      a.songCount,
      b.songCount,
      descending: descending,
    ),
    ArtistSortField.albumCount => compareNullsLast(
      a.albumCount,
      b.albumCount,
      descending: descending,
    ),
  };
  if (primary != 0) return primary;
  final name = compareText(a.name, b.name);
  return name != 0 ? name : a.key.compareTo(b.key);
}
