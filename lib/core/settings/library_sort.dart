/// What the Songs list can be sorted by.
enum SongSortField { title, artist, album, year, dateAdded, duration }

/// What the Albums screen can be sorted by.
enum AlbumSortField { title, artist, year, dateAdded }

/// What the Artists screen can be sorted by.
enum ArtistSortField { name, songCount, albumCount }

/// How the Albums screen lays out its albums.
enum AlbumsView { grid, list }

/// A screen's sort: the field and the direction.
class SortChoice<F extends Enum> {
  const SortChoice(this.field, {this.descending = false});

  final F field;
  final bool descending;

  SortChoice<F> copyWith({F? field, bool? descending}) => SortChoice(
    field ?? this.field,
    descending: descending ?? this.descending,
  );

  @override
  bool operator ==(Object other) =>
      other is SortChoice<F> &&
      other.field == field &&
      other.descending == descending;

  @override
  int get hashCode => Object.hash(field, descending);

  @override
  String toString() => '${field.name} ${descending ? 'desc' : 'asc'}';
}
