import '../../../core/database/library_database.dart';
import '../../../core/settings/library_sort.dart';
import '../sort_compare.dart';

/// An album with its texts lower-cased once, not on every comparison.
typedef _Keyed = ({AlbumSummary album, String title, String? artist});

/// [albums] in the order of [sort]. Ties fall back to the title ascending,
/// then to the key, so the order is stable. Text ignores case.
List<AlbumSummary> sortAlbums(
  List<AlbumSummary> albums,
  SortChoice<AlbumSortField> sort,
) {
  final keyed = <_Keyed>[
    for (final a in albums)
      (album: a, title: a.title.toLowerCase(), artist: a.artist?.toLowerCase()),
  ]..sort((a, b) => _compare(a, b, sort));
  return [for (final k in keyed) k.album];
}

int _compare(_Keyed a, _Keyed b, SortChoice<AlbumSortField> sort) {
  final descending = sort.descending;
  final primary = switch (sort.field) {
    AlbumSortField.title => compareNullsLast(
      a.title,
      b.title,
      descending: descending,
    ),
    AlbumSortField.artist => compareNullsLast(
      a.artist,
      b.artist,
      descending: descending,
    ),
    AlbumSortField.year => compareNullsLast(
      a.album.year,
      b.album.year,
      descending: descending,
    ),
    AlbumSortField.dateAdded => compareNullsLast(
      a.album.addedAt,
      b.album.addedAt,
      descending: descending,
    ),
  };
  if (primary != 0) return primary;
  final title = a.title.compareTo(b.title);
  if (title != 0) return title;
  final ak = a.album.key, bk = b.album.key;
  final artistKey = ak.artistKey.compareTo(bk.artistKey);
  return artistKey != 0 ? artistKey : ak.titleKey.compareTo(bk.titleKey);
}
