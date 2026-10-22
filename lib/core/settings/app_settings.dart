import 'library_sort.dart';

export 'library_sort.dart';

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
  /// reduced-motion setting. Stored for the option that is not wired yet:
  /// nothing reads it.
  final bool animations;

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
      other.animations == animations;

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
  );

  @override
  String toString() =>
      'AppSettings(theme: ${theme.name}, language: $languageCode, '
      'titleBar: ${titleBar.name}, songSort: $songSort, '
      'albumSort: $albumSort, artistSort: $artistSort, '
      'albumsView: ${albumsView.name}, rescanOnStartup: $rescanOnStartup, '
      'libraryOnboarded: $libraryOnboarded, '
      'recordListenHistory: $recordListenHistory, animations: $animations)';
}
