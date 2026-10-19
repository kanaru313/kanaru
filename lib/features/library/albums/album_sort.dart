import '../../../core/database/library_database.dart';
import '../../../core/settings/library_sort.dart';
import '../sort_compare.dart';

/// [albums] in the order of [sort]. Ties fall back to the title ascending,
/// then to the key, so the order is stable.
List<AlbumSummary> sortAlbums(
  List<AlbumSummary> albums,
  SortChoice<AlbumSortField> sort,
) => [...albums]..sort((a, b) => compareAlbums(a, b, sort));

int compareAlbums(
  AlbumSummary a,
  AlbumSummary b,
  SortChoice<AlbumSortField> sort,
) {
  final descending = sort.descending;
  final primary = switch (sort.field) {
    AlbumSortField.title => compareText(
      a.title,
      b.title,
      descending: descending,
    ),
    AlbumSortField.artist => compareText(
      a.artist,
      b.artist,
      descending: descending,
    ),
    AlbumSortField.year => compareNullsLast(
      a.year,
      b.year,
      descending: descending,
    ),
    AlbumSortField.dateAdded => compareNullsLast(
      a.addedAt,
      b.addedAt,
      descending: descending,
    ),
  };
  if (primary != 0) return primary;
  final title = compareText(a.title, b.title);
  if (title != 0) return title;
  final artistKey = a.key.artistKey.compareTo(b.key.artistKey);
  return artistKey != 0 ? artistKey : a.key.titleKey.compareTo(b.key.titleKey);
}
