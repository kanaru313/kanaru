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
  String get onboardingTitle => 'Welcome to Kanaru';

  @override
  String get onboardingMessage =>
      'Choose the folders that hold your music. Kanaru scans them and builds your library.';

  @override
  String get onboardingSuggested => 'Suggested';

  @override
  String get onboardingAdded => 'Your folders';

  @override
  String get onboardingNoFolders => 'No folder chosen yet.';

  @override
  String get onboardingAddFolder => 'Add folder…';

  @override
  String get onboardingRemoveFolder => 'Remove';

  @override
  String get onboardingLater => 'Later';

  @override
  String get onboardingStart => 'Start';

  @override
  String get libraryUnavailableTitle => 'Couldn\'t open the library';

  @override
  String get libraryUnavailableMessage =>
      'Playback still works. The log has the details.';

  @override
  String get libraryChooseFolder => 'Choose music folder';

  @override
  String get libraryNoTracksTitle => 'No songs found';

  @override
  String get libraryNoTracksMessage =>
      'Add music to your folders, then rescan.';

  @override
  String get libraryRescan => 'Rescan';

  @override
  String get libraryScanDiscovering => 'Looking for music files…';

  @override
  String libraryScanReading(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Reading tags $doneString / $totalString';
  }

  @override
  String get libraryScanDoneTitle => 'Scan complete';

  @override
  String get libraryScanWarningTitle => 'Scan complete, with warnings';

  @override
  String get libraryScanFailedTitle => 'Scan failed';

  @override
  String get libraryScanNoChanges => 'No changes';

  @override
  String libraryScanAdded(int count) {
    return '$count new';
  }

  @override
  String libraryScanUpdated(int count) {
    return '$count updated';
  }

  @override
  String libraryScanRemoved(int count) {
    return '$count removed';
  }

  @override
  String libraryScanFailedTags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files couldn\'t be read',
      one: '1 file couldn\'t be read',
    );
    return '$_temp0';
  }

  @override
  String libraryScanRootMissing(String path) {
    return '$path was not found';
  }

  @override
  String libraryScanRootEmpty(String path) {
    return '$path is empty, library kept as it was';
  }

  @override
  String libraryRootNotFound(String path) {
    return '$path was not found';
  }

  @override
  String libraryRootNotDirectory(String path) {
    return '$path is not a folder';
  }

  @override
  String libraryRootDuplicate(String path) {
    return '$path is already added';
  }

  @override
  String libraryRootNested(String path) {
    return '$path overlaps a folder that is already added';
  }

  @override
  String get libraryRootUnavailable => 'The library is not available';

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
  String settingsReadOnly(String path) {
    return 'Settings can\'t be saved this session ($path)';
  }

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
