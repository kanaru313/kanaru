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

  LibraryScanPrefs copyWith({
    bool? respectNomedia,
    bool? duplicatesByFilename,
    bool? m3uPlaylists,
    AlbumGrouping? albumGrouping,
    int? minFileSizeKb,
    int? minDurationSeconds,
    bool? watchFolders,
  }) => LibraryScanPrefs(
    respectNomedia: respectNomedia ?? this.respectNomedia,
    duplicatesByFilename: duplicatesByFilename ?? this.duplicatesByFilename,
    m3uPlaylists: m3uPlaylists ?? this.m3uPlaylists,
    albumGrouping: albumGrouping ?? this.albumGrouping,
    minFileSizeKb: minFileSizeKb ?? this.minFileSizeKb,
    minDurationSeconds: minDurationSeconds ?? this.minDurationSeconds,
    watchFolders: watchFolders ?? this.watchFolders,
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
      other.watchFolders == watchFolders;

  @override
  int get hashCode => Object.hash(
    respectNomedia,
    duplicatesByFilename,
    m3uPlaylists,
    albumGrouping,
    minFileSizeKb,
    minDurationSeconds,
    watchFolders,
  );

  @override
  String toString() =>
      'LibraryScanPrefs(respectNomedia: $respectNomedia, '
      'duplicatesByFilename: $duplicatesByFilename, '
      'm3uPlaylists: $m3uPlaylists, albumGrouping: $albumGrouping, '
      'minFileSizeKb: $minFileSizeKb, '
      'minDurationSeconds: $minDurationSeconds, '
      'watchFolders: $watchFolders)';
}
