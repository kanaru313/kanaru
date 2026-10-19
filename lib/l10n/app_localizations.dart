import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Kanaru'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get navSongs;

  /// No description provided for @navAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get navAlbums;

  /// No description provided for @navArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get navArtists;

  /// No description provided for @navFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get navFolders;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// No description provided for @navRecentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get navRecentlyPlayed;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @sidebarPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get sidebarPlaylists;

  /// No description provided for @sidebarNoPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get sidebarNoPlaylists;

  /// No description provided for @sidebarNewPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get sidebarNewPlaylist;

  /// No description provided for @sidebarExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get sidebarExpand;

  /// No description provided for @sidebarCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get sidebarCollapse;

  /// No description provided for @sidebarShrink.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get sidebarShrink;

  /// No description provided for @sidebarGrow.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get sidebarGrow;

  /// No description provided for @topBarBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get topBarBack;

  /// No description provided for @topBarForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get topBarForward;

  /// No description provided for @topBarSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search songs, albums, artists'**
  String get topBarSearchHint;

  /// No description provided for @windowMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get windowMinimize;

  /// No description provided for @windowMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get windowMaximize;

  /// No description provided for @windowRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get windowRestore;

  /// No description provided for @windowClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get windowClose;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick up where the music left off'**
  String get homeSubtitle;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a music folder to start building your library.'**
  String get libraryEmptyMessage;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Kanaru'**
  String get onboardingTitle;

  /// No description provided for @onboardingMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose the folders that hold your music. Kanaru scans them and builds your library.'**
  String get onboardingMessage;

  /// No description provided for @onboardingSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get onboardingSuggested;

  /// No description provided for @onboardingNoFolders.
  ///
  /// In en, this message translates to:
  /// **'No folder chosen yet.'**
  String get onboardingNoFolders;

  /// No description provided for @onboardingAddFolder.
  ///
  /// In en, this message translates to:
  /// **'Add folder…'**
  String get onboardingAddFolder;

  /// No description provided for @onboardingRemoveFolder.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get onboardingRemoveFolder;

  /// No description provided for @onboardingLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get onboardingLater;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get onboardingStart;

  /// No description provided for @libraryUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the library'**
  String get libraryUnavailableTitle;

  /// No description provided for @libraryUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Playback still works. The log has the details.'**
  String get libraryUnavailableMessage;

  /// No description provided for @libraryChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose music folder'**
  String get libraryChooseFolder;

  /// No description provided for @libraryNoTracksTitle.
  ///
  /// In en, this message translates to:
  /// **'No songs found'**
  String get libraryNoTracksTitle;

  /// No description provided for @libraryNoTracksMessage.
  ///
  /// In en, this message translates to:
  /// **'Add music to your folders, then rescan.'**
  String get libraryNoTracksMessage;

  /// No description provided for @libraryRescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get libraryRescan;

  /// No description provided for @libraryScanDiscovering.
  ///
  /// In en, this message translates to:
  /// **'Looking for music files…'**
  String get libraryScanDiscovering;

  /// No description provided for @libraryScanReading.
  ///
  /// In en, this message translates to:
  /// **'Reading tags {done} / {total}'**
  String libraryScanReading(int done, int total);

  /// No description provided for @libraryScanDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan complete'**
  String get libraryScanDoneTitle;

  /// No description provided for @libraryScanWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan complete, with warnings'**
  String get libraryScanWarningTitle;

  /// No description provided for @libraryScanFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan failed'**
  String get libraryScanFailedTitle;

  /// No description provided for @libraryScanNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes'**
  String get libraryScanNoChanges;

  /// No description provided for @libraryScanAdded.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String libraryScanAdded(int count);

  /// No description provided for @libraryScanUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count} updated'**
  String libraryScanUpdated(int count);

  /// No description provided for @libraryScanRemoved.
  ///
  /// In en, this message translates to:
  /// **'{count} removed'**
  String libraryScanRemoved(int count);

  /// No description provided for @libraryScanFailedTags.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 file couldn\'t be read} other{{count} files couldn\'t be read}}'**
  String libraryScanFailedTags(int count);

  /// No description provided for @libraryScanRootMissing.
  ///
  /// In en, this message translates to:
  /// **'{path} was not found'**
  String libraryScanRootMissing(String path);

  /// No description provided for @libraryScanRootEmpty.
  ///
  /// In en, this message translates to:
  /// **'{path} is empty, library kept as it was'**
  String libraryScanRootEmpty(String path);

  /// No description provided for @libraryRootNotFound.
  ///
  /// In en, this message translates to:
  /// **'{path} was not found'**
  String libraryRootNotFound(String path);

  /// No description provided for @libraryRootNotDirectory.
  ///
  /// In en, this message translates to:
  /// **'{path} is not a folder'**
  String libraryRootNotDirectory(String path);

  /// No description provided for @libraryRootDuplicate.
  ///
  /// In en, this message translates to:
  /// **'{path} is already added'**
  String libraryRootDuplicate(String path);

  /// No description provided for @libraryRootNested.
  ///
  /// In en, this message translates to:
  /// **'{path} overlaps a folder that is already added'**
  String libraryRootNested(String path);

  /// No description provided for @libraryRootUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The library is not available'**
  String get libraryRootUnavailable;

  /// No description provided for @libraryRootTooBroad.
  ///
  /// In en, this message translates to:
  /// **'{path} is too broad to be a music folder'**
  String libraryRootTooBroad(String path);

  /// No description provided for @libraryRootWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save {path}. See the log for details.'**
  String libraryRootWriteFailed(String path);

  /// No description provided for @libraryUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. See the log for details.'**
  String get libraryUnexpectedError;

  /// No description provided for @libraryScanFailedDetails.
  ///
  /// In en, this message translates to:
  /// **'See the log for details'**
  String get libraryScanFailedDetails;

  /// No description provided for @sortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortTooltip;

  /// No description provided for @sortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get sortAscending;

  /// No description provided for @sortDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get sortDescending;

  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortTitle;

  /// No description provided for @sortArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get sortArtist;

  /// No description provided for @sortAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get sortAlbum;

  /// No description provided for @sortYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get sortYear;

  /// No description provided for @sortDateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get sortDateAdded;

  /// No description provided for @sortDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get sortDuration;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided for @sortSongCount.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get sortSongCount;

  /// No description provided for @sortAlbumCount.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get sortAlbumCount;

  /// No description provided for @albumsGridView.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get albumsGridView;

  /// No description provided for @albumsListView.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get albumsListView;

  /// No description provided for @albumsNoRootsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a music folder in Songs.'**
  String get albumsNoRootsMessage;

  /// No description provided for @albumsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No albums yet'**
  String get albumsEmptyTitle;

  /// No description provided for @albumsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Songs with an album tag show up here as albums.'**
  String get albumsEmptyMessage;

  /// No description provided for @albumsUnknownArtist.
  ///
  /// In en, this message translates to:
  /// **'Unknown artist'**
  String get albumsUnknownArtist;

  /// No description provided for @albumsSongCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}}'**
  String albumsSongCount(int count);

  /// No description provided for @albumsPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get albumsPlay;

  /// No description provided for @albumsDisc.
  ///
  /// In en, this message translates to:
  /// **'Disc {number}'**
  String albumsDisc(int number);

  /// No description provided for @albumsUnknownDisc.
  ///
  /// In en, this message translates to:
  /// **'Unknown disc'**
  String get albumsUnknownDisc;

  /// No description provided for @albumsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Album not found'**
  String get albumsNotFound;

  /// No description provided for @albumsNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'It may have been removed or renamed by a rescan.'**
  String get albumsNotFoundMessage;

  /// No description provided for @artistsNoRootsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a music folder in Songs.'**
  String get artistsNoRootsMessage;

  /// No description provided for @artistsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No artists yet'**
  String get artistsEmptyTitle;

  /// No description provided for @artistsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Songs with an artist tag show up here by artist.'**
  String get artistsEmptyMessage;

  /// No description provided for @artistsAlbumCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 album} other{{count} albums}}'**
  String artistsAlbumCount(int count);

  /// No description provided for @artistsAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get artistsAlbums;

  /// No description provided for @artistsSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get artistsSongs;

  /// No description provided for @artistsAppearsOn.
  ///
  /// In en, this message translates to:
  /// **'Appears on'**
  String get artistsAppearsOn;

  /// No description provided for @artistsPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get artistsPlay;

  /// No description provided for @artistsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Artist not found'**
  String get artistsNotFound;

  /// No description provided for @artistsNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Their songs may have been removed or retagged.'**
  String get artistsNotFoundMessage;

  /// No description provided for @favoritesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Songs you like will show up here.'**
  String get favoritesEmptyMessage;

  /// No description provided for @recentlyPlayedEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Songs you play will show up here.'**
  String get recentlyPlayedEmptyMessage;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Search your library'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Find songs, albums and artists.'**
  String get searchEmptyMessage;

  /// No description provided for @searchResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Results for “{query}”'**
  String searchResultsTitle(String query);

  /// No description provided for @searchNotReadyMessage.
  ///
  /// In en, this message translates to:
  /// **'Search will work once your library has been scanned.'**
  String get searchNotReadyMessage;

  /// No description provided for @playerOpenMenu.
  ///
  /// In en, this message translates to:
  /// **'Open music'**
  String get playerOpenMenu;

  /// No description provided for @playerOpenFiles.
  ///
  /// In en, this message translates to:
  /// **'Open files…'**
  String get playerOpenFiles;

  /// No description provided for @playerOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder…'**
  String get playerOpenFolder;

  /// No description provided for @playerScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning folder…'**
  String get playerScanning;

  /// No description provided for @playerNoAudioFound.
  ///
  /// In en, this message translates to:
  /// **'No audio files found'**
  String get playerNoAudioFound;

  /// No description provided for @playerPlaybackError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play {title}'**
  String playerPlaybackError(String title);

  /// No description provided for @playerPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerPlay;

  /// No description provided for @playerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerPause;

  /// No description provided for @playerPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get playerPrevious;

  /// No description provided for @playerNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get playerNext;

  /// No description provided for @playerShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get playerShuffle;

  /// No description provided for @playerRepeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get playerRepeatOff;

  /// No description provided for @playerRepeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get playerRepeatAll;

  /// No description provided for @playerRepeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get playerRepeatOne;

  /// No description provided for @playerMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get playerMute;

  /// No description provided for @playerUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get playerUnmute;

  /// No description provided for @playerVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get playerVolume;

  /// No description provided for @playerSeek.
  ///
  /// In en, this message translates to:
  /// **'Seek'**
  String get playerSeek;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsTitleBar.
  ///
  /// In en, this message translates to:
  /// **'Title bar'**
  String get settingsTitleBar;

  /// No description provided for @settingsTitleBarKanaru.
  ///
  /// In en, this message translates to:
  /// **'Kanaru'**
  String get settingsTitleBarKanaru;

  /// No description provided for @settingsTitleBarSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsTitleBarSystem;

  /// No description provided for @settingsTitleBarNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingsTitleBarNone;

  /// No description provided for @settingsRestartRequired.
  ///
  /// In en, this message translates to:
  /// **'Applies after restart'**
  String get settingsRestartRequired;

  /// No description provided for @settingsReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Settings can\'t be saved this session ({path})'**
  String settingsReadOnly(String path);

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get settingsLicense;

  /// No description provided for @settingsSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get settingsSourceCode;

  /// No description provided for @settingsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open {target}'**
  String settingsOpenFailed(String target);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
