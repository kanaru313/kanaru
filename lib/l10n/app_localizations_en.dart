// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kanaru';

  @override
  String get navHome => 'Home';

  @override
  String get navSongs => 'Songs';

  @override
  String get navAlbums => 'Albums';

  @override
  String get navArtists => 'Artists';

  @override
  String get navFolders => 'Folders';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navRecentlyPlayed => 'Recently played';

  @override
  String get navSearch => 'Search';

  @override
  String get navSettings => 'Settings';

  @override
  String get sidebarPlaylists => 'Playlists';

  @override
  String get sidebarNoPlaylists => 'No playlists yet';

  @override
  String get sidebarNewPlaylist => 'New playlist';

  @override
  String get sidebarExpand => 'Expand';

  @override
  String get sidebarCollapse => 'Collapse';

  @override
  String get sidebarShrink => 'Collapse sidebar';

  @override
  String get sidebarGrow => 'Expand sidebar';

  @override
  String get topBarBack => 'Back';

  @override
  String get topBarForward => 'Forward';

  @override
  String get topBarSearchHint => 'Search songs, albums, artists';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowRestore => 'Restore';

  @override
  String get windowClose => 'Close';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeSubtitle => 'Pick up where the music left off';

  @override
  String get libraryEmptyTitle => 'Your library is empty';

  @override
  String get libraryEmptyMessage =>
      'Add a music folder to start building your library.';

  @override
  String get favoritesEmptyMessage => 'Songs you like will show up here.';

  @override
  String get recentlyPlayedEmptyMessage => 'Songs you play will show up here.';

  @override
  String get searchEmptyTitle => 'Search your library';

  @override
  String get searchEmptyMessage => 'Find songs, albums and artists.';

  @override
  String searchResultsTitle(String query) {
    return 'Results for “$query”';
  }

  @override
  String get searchNotReadyMessage =>
      'Search will work once your library has been scanned.';

  @override
  String get playerOpenMenu => 'Open music';

  @override
  String get playerOpenFiles => 'Open files…';

  @override
  String get playerOpenFolder => 'Open folder…';

  @override
  String get playerScanning => 'Scanning folder…';

  @override
  String get playerNoAudioFound => 'No audio files found';

  @override
  String playerPlaybackError(String title) {
    return 'Couldn\'t play $title';
  }

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerPrevious => 'Previous';

  @override
  String get playerNext => 'Next';

  @override
  String get playerShuffle => 'Shuffle';

  @override
  String get playerRepeatOff => 'Repeat off';

  @override
  String get playerRepeatAll => 'Repeat all';

  @override
  String get playerRepeatOne => 'Repeat one';

  @override
  String get playerMute => 'Mute';

  @override
  String get playerUnmute => 'Unmute';

  @override
  String get playerVolume => 'Volume';

  @override
  String get playerSeek => 'Seek';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsTitleBar => 'Title bar';

  @override
  String get settingsTitleBarKanaru => 'Kanaru';

  @override
  String get settingsTitleBarSystem => 'System';

  @override
  String get settingsTitleBarNone => 'None';

  @override
  String get settingsRestartRequired => 'Applies after restart';

  @override
  String get settingsAdvanced => 'Advanced';

  @override
  String settingsReadOnly(String path) {
    return 'Settings can\'t be saved this session ($path)';
  }

  @override
  String get settingsReset => 'Reset all settings';

  @override
  String get settingsResetConfirmTitle => 'Reset all settings?';

  @override
  String get settingsResetConfirmMessage =>
      'Theme, language and title bar go back to their defaults.';

  @override
  String get settingsResetConfirm => 'Reset';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsResetDone => 'Settings were reset';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsLicense => 'License';

  @override
  String get settingsSourceCode => 'Source code';

  @override
  String settingsOpenFailed(String target) {
    return 'Couldn\'t open $target';
  }
}
