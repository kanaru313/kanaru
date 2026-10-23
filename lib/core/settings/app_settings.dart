import 'display_prefs.dart';
import 'library_scan_prefs.dart';
import 'library_sort.dart';
import 'playback_prefs.dart';

export 'display_prefs.dart';
export 'library_scan_prefs.dart';
export 'library_sort.dart';
export 'playback_prefs.dart';

/// Light or dark theme, or whatever the desktop uses.
enum ThemePreference { system, light, dark }

/// Who draws the window's title bar.
enum TitleBarPreference {
  /// Kanaru's own top bar with window buttons.
  kanaru,

  /// The native one. On Wayland that is GTK's header bar, since the runner
  /// always creates one there.
  system,

  /// None at all, for tiling window managers that draw no decorations.
  none,
}

/// The user's preferences, as stored in `settings.json`.
///
/// Only non-secret preferences belong here: the file is plain text and may
/// be attached to bug reports. Credentials go to the system keyring.
class AppSettings {
  const AppSettings({
    this.theme = ThemePreference.system,
    this.languageCode,
    this.titleBar = TitleBarPreference.kanaru,
    this.songSort = const SortChoice(SongSortField.title),
    this.albumSort = const SortChoice(AlbumSortField.title),
    this.artistSort = const SortChoice(ArtistSortField.name),
    this.albumsView = AlbumsView.grid,
    this.rescanOnStartup = true,
    this.libraryOnboarded = false,
    this.recordListenHistory = true,
    this.animations = true,
    this.libraryScan = const LibraryScanPrefs(),
    this.playback = const PlaybackPrefs(),
    this.display = const DisplayPrefs(),
  });

  final ThemePreference theme;

  /// UI language such as `vi`, or `null` to follow the system. Whether the
  /// app has a translation for it is decided by the app, not here.
  final String? languageCode;

  final TitleBarPreference titleBar;

  /// Sort of each library screen, remembered separately.
  final SortChoice<SongSortField> songSort;
  final SortChoice<AlbumSortField> albumSort;
  final SortChoice<ArtistSortField> artistSort;

  final AlbumsView albumsView;

  /// Scan the library folders in the background when the app opens.
  final bool rescanOnStartup;

  /// The first-run source picker has been dealt with (a folder was added or
  /// "Later" was chosen), so it never comes back, even with no folders.
  final bool libraryOnboarded;

  /// Record listens to the play history (STAT-10). Turning it off keeps what
  /// is stored.
  final bool recordListenHistory;

  /// `false` forces reduced motion everywhere; `true` follows the system's
  /// reduced-motion setting. Read by the app's builder (`lib/app/app.dart`),
  /// which sets `MediaQuery.disableAnimations` for every page.
  final bool animations;

  /// Library scan, playback and display options, grouped so that this class
  /// stays small. Their defaults are today's behavior. Read today: the scan
  /// filters (`.nomedia`, size, duration) and folder watching, ReplayGain
  /// and the output device, the play/pause fades, the endless queue, the
  /// listen threshold, the color taken from the cover, the font size and the
  /// track numbers on album pages. The others are stored for features that
  /// are not built yet: nothing reads them.
  final LibraryScanPrefs libraryScan;
  final PlaybackPrefs playback;
  final DisplayPrefs display;

  AppSettings copyWith({
    ThemePreference? theme,
    TitleBarPreference? titleBar,
    SortChoice<SongSortField>? songSort,
    SortChoice<AlbumSortField>? albumSort,
    SortChoice<ArtistSortField>? artistSort,
    AlbumsView? albumsView,
    bool? rescanOnStartup,
    bool? libraryOnboarded,
    bool? recordListenHistory,
    bool? animations,
    LibraryScanPrefs? libraryScan,
    PlaybackPrefs? playback,
    DisplayPrefs? display,
  }) => AppSettings(
    theme: theme ?? this.theme,
    languageCode: languageCode,
    titleBar: titleBar ?? this.titleBar,
    songSort: songSort ?? this.songSort,
    albumSort: albumSort ?? this.albumSort,
    artistSort: artistSort ?? this.artistSort,
    albumsView: albumsView ?? this.albumsView,
    rescanOnStartup: rescanOnStartup ?? this.rescanOnStartup,
    libraryOnboarded: libraryOnboarded ?? this.libraryOnboarded,
    recordListenHistory: recordListenHistory ?? this.recordListenHistory,
    animations: animations ?? this.animations,
    libraryScan: libraryScan ?? this.libraryScan,
    playback: playback ?? this.playback,
    display: display ?? this.display,
  );

  /// Separate from [copyWith] because `null` is a valid language here.
  AppSettings withLanguage(String? languageCode) => AppSettings(
    theme: theme,
    languageCode: languageCode,
    titleBar: titleBar,
    songSort: songSort,
    albumSort: albumSort,
    artistSort: artistSort,
    albumsView: albumsView,
    rescanOnStartup: rescanOnStartup,
    libraryOnboarded: libraryOnboarded,
    recordListenHistory: recordListenHistory,
    animations: animations,
    libraryScan: libraryScan,
    playback: playback,
    display: display,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.theme == theme &&
      other.languageCode == languageCode &&
      other.titleBar == titleBar &&
      other.songSort == songSort &&
      other.albumSort == albumSort &&
      other.artistSort == artistSort &&
      other.albumsView == albumsView &&
      other.rescanOnStartup == rescanOnStartup &&
      other.libraryOnboarded == libraryOnboarded &&
      other.recordListenHistory == recordListenHistory &&
      other.animations == animations &&
      other.libraryScan == libraryScan &&
      other.playback == playback &&
      other.display == display;

  @override
  int get hashCode => Object.hash(
    theme,
    languageCode,
    titleBar,
    songSort,
    albumSort,
    artistSort,
    albumsView,
    rescanOnStartup,
    libraryOnboarded,
    recordListenHistory,
    animations,
    libraryScan,
    playback,
    display,
  );

  @override
  String toString() =>
      'AppSettings(theme: ${theme.name}, language: $languageCode, '
      'titleBar: ${titleBar.name}, songSort: $songSort, '
      'albumSort: $albumSort, artistSort: $artistSort, '
      'albumsView: ${albumsView.name}, rescanOnStartup: $rescanOnStartup, '
      'libraryOnboarded: $libraryOnboarded, '
      'recordListenHistory: $recordListenHistory, animations: $animations, '
      'libraryScan: $libraryScan, playback: $playback, display: $display)';
}
