import 'package:flutter/foundation.dart' show setEquals;

/// A destination of the sidebar that can be hidden. Declared here so that
/// `core` does not import the app shell.
enum SidebarTab { songs, albums, artists, folders, genres, languages }

const _allTabs = {
  SidebarTab.songs,
  SidebarTab.albums,
  SidebarTab.artists,
  SidebarTab.folders,
  SidebarTab.genres,
  SidebarTab.languages,
};

/// Smallest and largest [DisplayPrefs.fontScale].
const minFontScale = 0.8;
const maxFontScale = 1.5;

/// How the app looks beyond the theme. The defaults are what the app shows
/// today. Only [colorFromCover] is read (the cover palette and the scan);
/// [fontScale], [sidebarTabs] and [trackNumbersInAlbum] are stored for
/// display options that do not exist yet: nothing reads them.
class DisplayPrefs {
  const DisplayPrefs({
    this.colorFromCover = false,
    this.fontScale = 1.0,
    this.sidebarTabs = _allTabs,
    this.trackNumbersInAlbum = true,
  });

  /// Tint the app with colors taken from the cover being played.
  final bool colorFromCover;

  /// Multiplies every text size; 1.0 leaves them alone.
  final double fontScale;

  /// The sidebar destinations that show. Never empty. The file stores the
  /// hidden ones instead, so a destination added later shows by default.
  final Set<SidebarTab> sidebarTabs;

  /// Show the track number in front of each song on an album page.
  final bool trackNumbersInAlbum;

  DisplayPrefs copyWith({
    bool? colorFromCover,
    double? fontScale,
    Set<SidebarTab>? sidebarTabs,
    bool? trackNumbersInAlbum,
  }) => DisplayPrefs(
    colorFromCover: colorFromCover ?? this.colorFromCover,
    fontScale: fontScale ?? this.fontScale,
    sidebarTabs: sidebarTabs == null
        ? this.sidebarTabs
        : Set.unmodifiable(sidebarTabs),
    trackNumbersInAlbum: trackNumbersInAlbum ?? this.trackNumbersInAlbum,
  );

  @override
  bool operator ==(Object other) =>
      other is DisplayPrefs &&
      other.colorFromCover == colorFromCover &&
      other.fontScale == fontScale &&
      setEquals(other.sidebarTabs, sidebarTabs) &&
      other.trackNumbersInAlbum == trackNumbersInAlbum;

  @override
  int get hashCode => Object.hash(
    colorFromCover,
    fontScale,
    Object.hashAllUnordered(sidebarTabs),
    trackNumbersInAlbum,
  );

  @override
  String toString() =>
      'DisplayPrefs(colorFromCover: $colorFromCover, fontScale: $fontScale, '
      'sidebarTabs: ${sidebarTabs.map((t) => t.name).join(',')}, '
      'trackNumbersInAlbum: $trackNumbersInAlbum)';
}
