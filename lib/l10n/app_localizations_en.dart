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
  String get settingsEmptyMessage => 'Nothing to configure yet.';
}
