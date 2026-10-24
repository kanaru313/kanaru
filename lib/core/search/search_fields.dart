/// Which parts of a song the free text of a search looks at, and the presets
/// the search page offers. Pure Dart.
library;

/// One searchable part of a song.
enum SearchField { title, artist, album, albumArtist, genre, fileName, comment }

/// The full-text columns, in the column order of `track_search` (bm25 weights
/// are positional, so the order must not change).
const _ftsColumnByField = <SearchField, String>{
  SearchField.title: 'title_sort',
  SearchField.artist: 'artist_search',
  SearchField.album: 'album_search',
  SearchField.albumArtist: 'album_artist_search',
  SearchField.genre: 'genre_search',
};

/// Ready-made choices of fields.
enum SearchFieldPreset {
  /// Every tag field: what search looked at before fields were selectable.
  /// File name and comment are left out to keep that behavior and speed;
  /// the user turns them on.
  all({
    SearchField.title,
    SearchField.artist,
    SearchField.album,
    SearchField.albumArtist,
    SearchField.genre,
  }),

  /// Titles only.
  titleOnly({SearchField.title});

  const SearchFieldPreset(this.fields);

  final Set<SearchField> fields;
}

/// The default choice.
Set<SearchField> get defaultSearchFields => SearchFieldPreset.all.fields;

/// Full-text columns for [fields], in `track_search` column order. File name
/// and comment have no column (they are matched by a Dart index).
List<String> ftsColumns(Set<SearchField> fields) => [
  for (final entry in _ftsColumnByField.entries)
    if (fields.contains(entry.key)) entry.value,
];

/// Whether [fields] ask for file name or comment text.
bool usesFileText(Set<SearchField> fields) =>
    fields.contains(SearchField.fileName) ||
    fields.contains(SearchField.comment);
