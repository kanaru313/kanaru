/// How albums are told apart. The album title always counts.
class AlbumGrouping {
  const AlbumGrouping({this.byAlbumArtist = true, this.byYear = false});

  /// Same title by different album artists are different albums.
  final bool byAlbumArtist;

  /// Same title in different years are different albums.
  final bool byYear;

  @override
  bool operator ==(Object other) =>
      other is AlbumGrouping &&
      other.byAlbumArtist == byAlbumArtist &&
      other.byYear == byYear;

  @override
  int get hashCode => Object.hash(byAlbumArtist, byYear);

  @override
  String toString() =>
      'AlbumGrouping(byAlbumArtist: $byAlbumArtist, byYear: $byYear)';
}

/// What separates the names in an artist tag: `;`, `,` and `//` anywhere, the
/// other entries as whole words (any case, whitespace on each side).
const defaultArtistSeparators = [
  ';',
  ',',
  '//',
  'feat.',
  'feat',
  'ft.',
  'ft',
  'featuring',
  'with',
];

/// Artist names that hold a separator and are one artist.
const defaultArtistKeepWhole = ['AC/DC'];

/// What separates the genres in a stored genre string.
const defaultGenreSeparators = [';'];

/// Longest entry kept in a [SplitPrefs] list, in characters.
const maxSplitEntryLength = 64;

/// Most entries kept in one [SplitPrefs] list.
const maxSplitEntries = 64;

/// How a tag holding several names is split: the [separators] and the
/// names that stay whole although they contain one ([keepWhole]). Both lists
/// are what the person typed; `SplitRules` (core/database) normalises them.
class SplitPrefs {
  const SplitPrefs({required this.separators, required this.keepWhole});

  final List<String> separators;
  final List<String> keepWhole;

  SplitPrefs copyWith({List<String>? separators, List<String>? keepWhole}) =>
      SplitPrefs(
        separators: separators ?? this.separators,
        keepWhole: keepWhole ?? this.keepWhole,
      );

  @override
  bool operator ==(Object other) =>
      other is SplitPrefs &&
      _sameStrings(other.separators, separators) &&
      _sameStrings(other.keepWhole, keepWhole);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(separators), Object.hashAll(keepWhole));

  @override
  String toString() =>
      'SplitPrefs(separators: $separators, keepWhole: $keepWhole)';
}

bool _sameStrings(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The usable entries of a [SplitPrefs] list: without control characters
/// (U+0000-U+001F, U+007F), trimmed, not empty, at most
/// [maxSplitEntryLength] characters (a longer one is dropped, not cut),
/// without repeats (any case), at most [maxSplitEntries] of them. Applied
/// both when settings are read and when rules are made from them, so the
/// rules of a session are the ones the next start gives.
List<String> cleanSplitEntries(Iterable<String> entries) {
  final seen = <String>{};
  final out = <String>[];
  for (final item in entries) {
    if (out.length >= maxSplitEntries) break;
    final text = String.fromCharCodes([
      for (final unit in item.codeUnits)
        if (unit >= 0x20 && unit != 0x7f) unit,
    ]).trim();
    if (text.isEmpty || text.runes.length > maxSplitEntryLength) continue;
    if (seen.add(text.toLowerCase())) out.add(text);
  }
  return out;
}

const defaultArtistSplit = SplitPrefs(
  separators: defaultArtistSeparators,
  keepWhole: defaultArtistKeepWhole,
);

const defaultGenreSplit = SplitPrefs(
  separators: defaultGenreSeparators,
  keepWhole: [],
);

/// Largest value of [LibraryScanPrefs.minFileSizeKb] (100 MB).
const maxMinFileSizeKb = 102400;

/// Largest value of [LibraryScanPrefs.minDurationSeconds].
const maxMinDurationSeconds = 600;

/// What a scan reads and keeps. The defaults are what the scan does today.
/// Each option is stored here first and wired to the scan later; a field's
/// doc says when it is read.
class LibraryScanPrefs {
  const LibraryScanPrefs({
    this.respectNomedia = false,
    this.duplicatesByFilename = false,
    this.m3uPlaylists = false,
    this.albumGrouping = const AlbumGrouping(),
    this.minFileSizeKb = 0,
    this.minDurationSeconds = 0,
    this.watchFolders = false,
    this.artistSplit = defaultArtistSplit,
    this.genreSplit = defaultGenreSplit,
  });

  /// Skip folders that hold a `.nomedia` file.
  final bool respectNomedia;

  /// Treat files with the same name as duplicates.
  final bool duplicatesByFilename;

  /// Read `.m3u` files as playlists.
  final bool m3uPlaylists;

  final AlbumGrouping albumGrouping;

  /// Skip files smaller than this; 0 keeps all.
  final int minFileSizeKb;

  /// Skip tracks shorter than this; 0 keeps all.
  final int minDurationSeconds;

  /// Rescan by itself when files in the music folders change while the app
  /// runs.
  final bool watchFolders;

  /// How the artist and album artist tags are split into artists. Read by
  /// the scan and by the key backfill; a change re-keys the library.
  final SplitPrefs artistSplit;

  /// How a stored genre string is split into genres. Read when the Genres
  /// list is built, so a change needs no re-key.
  final SplitPrefs genreSplit;

  LibraryScanPrefs copyWith({
    bool? respectNomedia,
    bool? duplicatesByFilename,
    bool? m3uPlaylists,
    AlbumGrouping? albumGrouping,
    int? minFileSizeKb,
    int? minDurationSeconds,
    bool? watchFolders,
    SplitPrefs? artistSplit,
    SplitPrefs? genreSplit,
  }) => LibraryScanPrefs(
    respectNomedia: respectNomedia ?? this.respectNomedia,
    duplicatesByFilename: duplicatesByFilename ?? this.duplicatesByFilename,
    m3uPlaylists: m3uPlaylists ?? this.m3uPlaylists,
    albumGrouping: albumGrouping ?? this.albumGrouping,
    minFileSizeKb: minFileSizeKb ?? this.minFileSizeKb,
    minDurationSeconds: minDurationSeconds ?? this.minDurationSeconds,
    watchFolders: watchFolders ?? this.watchFolders,
    artistSplit: artistSplit ?? this.artistSplit,
    genreSplit: genreSplit ?? this.genreSplit,
  );

  @override
  bool operator ==(Object other) =>
      other is LibraryScanPrefs &&
      other.respectNomedia == respectNomedia &&
      other.duplicatesByFilename == duplicatesByFilename &&
      other.m3uPlaylists == m3uPlaylists &&
      other.albumGrouping == albumGrouping &&
      other.minFileSizeKb == minFileSizeKb &&
      other.minDurationSeconds == minDurationSeconds &&
      other.watchFolders == watchFolders &&
      other.artistSplit == artistSplit &&
      other.genreSplit == genreSplit;

  @override
  int get hashCode => Object.hash(
    respectNomedia,
    duplicatesByFilename,
    m3uPlaylists,
    albumGrouping,
    minFileSizeKb,
    minDurationSeconds,
    watchFolders,
    artistSplit,
    genreSplit,
  );

  @override
  String toString() =>
      'LibraryScanPrefs(respectNomedia: $respectNomedia, '
      'duplicatesByFilename: $duplicatesByFilename, '
      'm3uPlaylists: $m3uPlaylists, albumGrouping: $albumGrouping, '
      'minFileSizeKb: $minFileSizeKb, '
      'minDurationSeconds: $minDurationSeconds, '
      'watchFolders: $watchFolders, artistSplit: $artistSplit, '
      'genreSplit: $genreSplit)';
}
