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
/// today. Read: [colorFromCover] (the cover palette and the scan),
/// [waveformSeekBar] (`NowPlayingSeekSlot`),
/// [fontScale] (the app's builder, `lib/app/app.dart`) and
/// [trackNumbersInAlbum] (album pages) and [sidebarTabs] (the sidebar).
class DisplayPrefs {
  const DisplayPrefs({
    this.colorFromCover = true,
    this.waveformSeekBar = true,
    this.fontScale = 1.0,
    this.sidebarTabs = _allTabs,
    this.trackNumbersInAlbum = true,
  });

  /// Tint the app with colors taken from the cover being played.
  final bool colorFromCover;

  /// Show the shape of the song in the seek bar of Now Playing; off shows
  /// the flat seek bar.
  final bool waveformSeekBar;

  /// Multiplies every text size, on top of the system's text scale; 1.0
  /// leaves them alone. Enlarging stops at twice the normal size (or the
  /// system's scale when larger), see `appTextScaler`.
  final double fontScale;

  /// The sidebar destinations that show. Never empty. The file stores the
  /// hidden ones instead, so a destination added later shows by default.
  final Set<SidebarTab> sidebarTabs;

  /// Show the track number in front of each song on an album page; off shows
  /// the song's cover there instead.
  final bool trackNumbersInAlbum;

  DisplayPrefs copyWith({
    bool? colorFromCover,
    bool? waveformSeekBar,
    double? fontScale,
    Set<SidebarTab>? sidebarTabs,
    bool? trackNumbersInAlbum,
  }) => DisplayPrefs(
    colorFromCover: colorFromCover ?? this.colorFromCover,
    waveformSeekBar: waveformSeekBar ?? this.waveformSeekBar,
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
      other.waveformSeekBar == waveformSeekBar &&
      other.fontScale == fontScale &&
      setEquals(other.sidebarTabs, sidebarTabs) &&
      other.trackNumbersInAlbum == trackNumbersInAlbum;

  @override
  int get hashCode => Object.hash(
    colorFromCover,
    waveformSeekBar,
    fontScale,
    Object.hashAllUnordered(sidebarTabs),
    trackNumbersInAlbum,
  );

  @override
  String toString() =>
      'DisplayPrefs(colorFromCover: $colorFromCover, '
      'waveformSeekBar: $waveformSeekBar, fontScale: $fontScale, '
      'sidebarTabs: ${sidebarTabs.map((t) => t.name).join(',')}, '
      'trackNumbersInAlbum: $trackNumbersInAlbum)';
}
