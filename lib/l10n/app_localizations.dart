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

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// Name of the page ranking songs by plays in a date range, in the sidebar and as its title
  ///
  /// In en, this message translates to:
  /// **'Most played'**
  String get navMostPlayed;

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

  /// No description provided for @playlistDefaultName.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get playlistDefaultName;

  /// No description provided for @playlistCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get playlistCreateTitle;

  /// No description provided for @playlistCreateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get playlistCreateConfirm;

  /// No description provided for @playlistRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get playlistRename;

  /// No description provided for @playlistRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get playlistRenameTitle;

  /// No description provided for @playlistNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get playlistNameLabel;

  /// No description provided for @playlistDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist'**
  String get playlistDelete;

  /// No description provided for @playlistDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String playlistDeleteTitle(String name);

  /// No description provided for @playlistDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{It has no songs.} =1{It has 1 song.} other{It has {count} songs.}} The songs stay in your library.'**
  String playlistDeleteBody(int count);

  /// No description provided for @playlistDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get playlistDeleteConfirm;

  /// No description provided for @playlistActions.
  ///
  /// In en, this message translates to:
  /// **'Playlist actions'**
  String get playlistActions;

  /// No description provided for @playlistTrackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No songs} =1{1 song} other{{count} songs}}'**
  String playlistTrackCount(int count);

  /// No description provided for @playlistEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'This playlist is empty'**
  String get playlistEmptyTitle;

  /// No description provided for @playlistEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add songs from the menu of any song, album or artist.'**
  String get playlistEmptyMessage;

  /// No description provided for @playlistsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a playlist to keep songs in your own order.'**
  String get playlistsEmptyMessage;

  /// No description provided for @playlistNotFound.
  ///
  /// In en, this message translates to:
  /// **'Playlist not found'**
  String get playlistNotFound;

  /// No description provided for @playlistNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted.'**
  String get playlistNotFoundMessage;

  /// No description provided for @playlistNotInLibrary.
  ///
  /// In en, this message translates to:
  /// **'Not in library'**
  String get playlistNotInLibrary;

  /// No description provided for @playlistRemoveEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get playlistRemoveEntry;

  /// No description provided for @playlistReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get playlistReorder;

  /// No description provided for @playlistAddTo.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist…'**
  String get playlistAddTo;

  /// No description provided for @playlistPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get playlistPickerTitle;

  /// No description provided for @playlistPickerNew.
  ///
  /// In en, this message translates to:
  /// **'New playlist…'**
  String get playlistPickerNew;

  /// No description provided for @playlistAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to {playlist}: {name}'**
  String playlistAdded(String name, String playlist);

  /// No description provided for @playlistAddedSkipped.
  ///
  /// In en, this message translates to:
  /// **'{added, plural, =1{Added 1 song to {playlist}} other{Added {added} songs to {playlist}}}, {skipped, plural, =1{1 was already there} other{{skipped} were already there}}'**
  String playlistAddedSkipped(int added, int skipped, String playlist);

  /// No description provided for @playlistAlreadyIn.
  ///
  /// In en, this message translates to:
  /// **'Already in {playlist}: {name}'**
  String playlistAlreadyIn(String name, String playlist);

  /// No description provided for @playlistSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the playlist. See the log for details.'**
  String get playlistSaveFailed;

  /// No description provided for @playlistTrackNotInLibrary.
  ///
  /// In en, this message translates to:
  /// **'This song isn\'t in your library, so it can\'t go in a playlist.'**
  String get playlistTrackNotInLibrary;

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

  /// No description provided for @libraryShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get libraryShuffle;

  /// No description provided for @libraryShowArtist.
  ///
  /// In en, this message translates to:
  /// **'Show artist'**
  String get libraryShowArtist;

  /// No description provided for @libraryShowAlbum.
  ///
  /// In en, this message translates to:
  /// **'Show album'**
  String get libraryShowAlbum;

  /// No description provided for @libraryShowInFileManager.
  ///
  /// In en, this message translates to:
  /// **'Show in file manager'**
  String get libraryShowInFileManager;

  /// No description provided for @libraryFileManagerFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the file manager'**
  String get libraryFileManagerFailed;

  /// No description provided for @libraryTrackGone.
  ///
  /// In en, this message translates to:
  /// **'This song is no longer in the library'**
  String get libraryTrackGone;

  /// No description provided for @libraryNoAlbumToShow.
  ///
  /// In en, this message translates to:
  /// **'This song has no album'**
  String get libraryNoAlbumToShow;

  /// No description provided for @libraryNoArtistToShow.
  ///
  /// In en, this message translates to:
  /// **'This song has no artist'**
  String get libraryNoArtistToShow;

  /// No description provided for @libraryChooseArtist.
  ///
  /// In en, this message translates to:
  /// **'Choose an artist'**
  String get libraryChooseArtist;

  /// No description provided for @libraryKeysUpdatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Updating library…'**
  String get libraryKeysUpdatingTitle;

  /// No description provided for @libraryKeysUpdatingMessage.
  ///
  /// In en, this message translates to:
  /// **'Sorting your music. Playback keeps working.'**
  String get libraryKeysUpdatingMessage;

  /// No description provided for @libraryKeysUpdatingProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total}'**
  String libraryKeysUpdatingProgress(int done, int total);

  /// No description provided for @libraryCoverProgress.
  ///
  /// In en, this message translates to:
  /// **'Making covers… {done} / {total}'**
  String libraryCoverProgress(int done, int total);

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

  /// No description provided for @libraryScanUndecodableNames.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 file or folder skipped: its name is not valid UTF-8} other{{count} files or folders skipped: names are not valid UTF-8}}'**
  String libraryScanUndecodableNames(int count);

  /// No description provided for @libraryScanRootMissing.
  ///
  /// In en, this message translates to:
  /// **'{path} was not found'**
  String libraryScanRootMissing(String path);

  /// No description provided for @libraryMissingRoots.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Music folder not found: {path}} other{{count} music folders not found}}'**
  String libraryMissingRoots(int count, String path);

  /// No description provided for @libraryMissingRootsAction.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get libraryMissingRootsAction;

  /// No description provided for @libraryScanRootEmpty.
  ///
  /// In en, this message translates to:
  /// **'{path} is empty, library kept as it was'**
  String libraryScanRootEmpty(String path);

  /// No description provided for @libraryScanRootTimedOut.
  ///
  /// In en, this message translates to:
  /// **'{path} took too long, stopped. If the folder was still being read, the scan finishes by itself when it is done'**
  String libraryScanRootTimedOut(String path);

  /// No description provided for @libraryScanRootReaderStuck.
  ///
  /// In en, this message translates to:
  /// **'{path} was not read: an earlier read is still running. It is tried again automatically when that read finishes; if it never does, restart Kanaru'**
  String libraryScanRootReaderStuck(String path);

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

  /// No description provided for @songsTrackGone.
  ///
  /// In en, this message translates to:
  /// **'That song is no longer in the library.'**
  String get songsTrackGone;

  /// No description provided for @songsShuffleAll.
  ///
  /// In en, this message translates to:
  /// **'Shuffle all'**
  String get songsShuffleAll;

  /// No description provided for @queuePlayNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get queuePlayNext;

  /// No description provided for @queueAddToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get queueAddToQueue;

  /// No description provided for @queueActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Queue actions'**
  String get queueActionsTooltip;

  /// No description provided for @queuePlayingNext.
  ///
  /// In en, this message translates to:
  /// **'Playing next: {name}'**
  String queuePlayingNext(String name);

  /// No description provided for @queuePlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing: {name}'**
  String queuePlaying(String name);

  /// No description provided for @queueAddedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added to queue: {name}'**
  String queueAddedToQueue(String name);

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by:'**
  String get sortBy;

  /// No description provided for @sortOrder.
  ///
  /// In en, this message translates to:
  /// **'Order:'**
  String get sortOrder;

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

  /// Total length of an album in its list row, in whole minutes
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String albumsMinutes(int count);

  /// Tooltip of the play button shown on an album row on hover
  ///
  /// In en, this message translates to:
  /// **'Play album'**
  String get albumsPlayAlbum;

  /// A total length of an hour or more in a library row
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String libraryHoursMinutes(int hours, int minutes);

  /// Tooltip of the play button shown on an artist row on hover
  ///
  /// In en, this message translates to:
  /// **'Play artist'**
  String get artistsPlayArtist;

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

  /// No description provided for @genresTitle.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get genresTitle;

  /// No description provided for @genresNoRootsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a music folder in Songs.'**
  String get genresNoRootsMessage;

  /// No description provided for @genresEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No genres yet'**
  String get genresEmptyTitle;

  /// No description provided for @genresEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Songs with a genre tag show up here by genre.'**
  String get genresEmptyMessage;

  /// No description provided for @genresAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get genresAlbums;

  /// No description provided for @genresNotFound.
  ///
  /// In en, this message translates to:
  /// **'Genre not found'**
  String get genresNotFound;

  /// No description provided for @genresNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Its songs may have been removed or retagged.'**
  String get genresNotFoundMessage;

  /// No description provided for @foldersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No folders yet'**
  String get foldersEmptyTitle;

  /// No description provided for @foldersEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Folders with songs show up here.'**
  String get foldersEmptyMessage;

  /// No description provided for @foldersNoRootsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a music folder in Songs.'**
  String get foldersNoRootsMessage;

  /// No description provided for @foldersNotFound.
  ///
  /// In en, this message translates to:
  /// **'Folder not found'**
  String get foldersNotFound;

  /// No description provided for @foldersNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'It may have been removed or no longer holds songs.'**
  String get foldersNotFoundMessage;

  /// No description provided for @foldersTreeView.
  ///
  /// In en, this message translates to:
  /// **'Folder tree'**
  String get foldersTreeView;

  /// No description provided for @foldersFlatView.
  ///
  /// In en, this message translates to:
  /// **'All folders'**
  String get foldersFlatView;

  /// No description provided for @foldersSubfolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get foldersSubfolders;

  /// No description provided for @foldersSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get foldersSongs;

  /// No description provided for @foldersCounts.
  ///
  /// In en, this message translates to:
  /// **'{songs, plural, =1{1 song} other{{songs} songs}}, {folders, plural, =0{no subfolders} =1{1 subfolder} other{{folders} subfolders}}'**
  String foldersCounts(int songs, int folders);

  /// No description provided for @foldersCreatePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create playlist'**
  String get foldersCreatePlaylist;

  /// No description provided for @foldersEmptyFolder.
  ///
  /// In en, this message translates to:
  /// **'No songs in this folder'**
  String get foldersEmptyFolder;

  /// No description provided for @favoritesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Songs you like will show up here.'**
  String get favoritesEmptyMessage;

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

  /// No description provided for @searchShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all ({count})'**
  String searchShowAll(int count);

  /// No description provided for @searchShowTop.
  ///
  /// In en, this message translates to:
  /// **'Show top {count}'**
  String searchShowTop(int count);

  /// No description provided for @searchShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get searchShowLess;

  /// No description provided for @searchFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchFailedTitle;

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchNoResultsTitle;

  /// No description provided for @searchNoResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches “{query}”. Try fewer or shorter words.'**
  String searchNoResultsMessage(String query);

  /// No description provided for @searchMoreSongs.
  ///
  /// In en, this message translates to:
  /// **'Showing the top {shown} of {total} songs. Add words to narrow it down.'**
  String searchMoreSongs(int shown, int total);

  /// No description provided for @searchNoResultsNarrowFields.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches “{query}” in the chosen fields. Try turning on more search fields.'**
  String searchNoResultsNarrowFields(String query);

  /// No description provided for @searchFieldsButton.
  ///
  /// In en, this message translates to:
  /// **'Search fields'**
  String get searchFieldsButton;

  /// No description provided for @searchFieldsFiltered.
  ///
  /// In en, this message translates to:
  /// **'Search fields (filtered)'**
  String get searchFieldsFiltered;

  /// No description provided for @searchPresetAll.
  ///
  /// In en, this message translates to:
  /// **'All fields'**
  String get searchPresetAll;

  /// No description provided for @searchPresetTitleOnly.
  ///
  /// In en, this message translates to:
  /// **'Titles only'**
  String get searchPresetTitleOnly;

  /// No description provided for @searchFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get searchFieldTitle;

  /// No description provided for @searchFieldArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get searchFieldArtist;

  /// No description provided for @searchFieldAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get searchFieldAlbum;

  /// No description provided for @searchFieldAlbumArtist.
  ///
  /// In en, this message translates to:
  /// **'Album artist'**
  String get searchFieldAlbumArtist;

  /// No description provided for @searchFieldGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get searchFieldGenre;

  /// No description provided for @searchFieldFileName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get searchFieldFileName;

  /// No description provided for @searchFieldComment.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get searchFieldComment;

  /// No description provided for @searchCorrectedResultsForPrefix.
  ///
  /// In en, this message translates to:
  /// **'Results for'**
  String get searchCorrectedResultsForPrefix;

  /// No description provided for @searchHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchHistoryTitle;

  /// No description provided for @searchHistoryRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from history'**
  String get searchHistoryRemove;

  /// No description provided for @searchHistoryClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get searchHistoryClearAll;

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
  /// **'Stop after the last song'**
  String get playerRepeatOff;

  /// No description provided for @playerRepeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat the whole queue'**
  String get playerRepeatAll;

  /// No description provided for @playerRepeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat the current song'**
  String get playerRepeatOne;

  /// No description provided for @playerRepeatAllShuffled.
  ///
  /// In en, this message translates to:
  /// **'Repeat the whole queue (shuffled)'**
  String get playerRepeatAllShuffled;

  /// Repeat menu item and button tooltip: play the current song this many extra times
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Repeat 1 more time} other{Repeat {count} more times}}'**
  String playerRepeatTimes(int count);

  /// No description provided for @playerRepeatFewer.
  ///
  /// In en, this message translates to:
  /// **'One time fewer'**
  String get playerRepeatFewer;

  /// No description provided for @playerRepeatMore.
  ///
  /// In en, this message translates to:
  /// **'One more time'**
  String get playerRepeatMore;

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

  /// No description provided for @nowPlayingOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Now Playing'**
  String get nowPlayingOpen;

  /// No description provided for @nowPlayingClose.
  ///
  /// In en, this message translates to:
  /// **'Close Now Playing'**
  String get nowPlayingClose;

  /// No description provided for @nowPlayingFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get nowPlayingFavorite;

  /// No description provided for @nowPlayingAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get nowPlayingAddToPlaylist;

  /// No description provided for @nowPlayingTabQueue.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nowPlayingTabQueue;

  /// No description provided for @nowPlayingTabTrack.
  ///
  /// In en, this message translates to:
  /// **'Song'**
  String get nowPlayingTabTrack;

  /// No description provided for @nowPlayingBackToTrack.
  ///
  /// In en, this message translates to:
  /// **'Back to the song'**
  String get nowPlayingBackToTrack;

  /// No description provided for @nowPlayingLyricsOnly.
  ///
  /// In en, this message translates to:
  /// **'Lyrics only'**
  String get nowPlayingLyricsOnly;

  /// No description provided for @nowPlayingViewSplit.
  ///
  /// In en, this message translates to:
  /// **'Split view'**
  String get nowPlayingViewSplit;

  /// No description provided for @nowPlayingViewCoverOnly.
  ///
  /// In en, this message translates to:
  /// **'Cover only'**
  String get nowPlayingViewCoverOnly;

  /// No description provided for @queueOpen.
  ///
  /// In en, this message translates to:
  /// **'Show now playing list'**
  String get queueOpen;

  /// No description provided for @queueTitle.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get queueTitle;

  /// No description provided for @queueTrackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 track} other{{count} tracks}}'**
  String queueTrackCount(int count);

  /// No description provided for @queueClear.
  ///
  /// In en, this message translates to:
  /// **'Clear queue'**
  String get queueClear;

  /// No description provided for @queueRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from queue'**
  String get queueRemove;

  /// Snackbar when a queue row menu item is picked after the queue was replaced or cleared
  ///
  /// In en, this message translates to:
  /// **'The queue changed, so nothing was done'**
  String get queueMenuStale;

  /// No description provided for @queueReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get queueReorder;

  /// No description provided for @queueShowCurrent.
  ///
  /// In en, this message translates to:
  /// **'Jump to current song'**
  String get queueShowCurrent;

  /// No description provided for @queueClose.
  ///
  /// In en, this message translates to:
  /// **'Close now playing list'**
  String get queueClose;

  /// Second line of the queue header: track count and time left
  ///
  /// In en, this message translates to:
  /// **'{tracks} · {timeLeft}'**
  String queueSummary(String tracks, String timeLeft);

  /// No description provided for @queueTimeLeftHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min left'**
  String queueTimeLeftHours(int hours, int minutes);

  /// No description provided for @queueTimeLeftMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min left'**
  String queueTimeLeftMinutes(int minutes);

  /// No description provided for @queueMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get queueMoreActions;

  /// No description provided for @settingsLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get settingsLibrary;

  /// No description provided for @settingsRescanLibrary.
  ///
  /// In en, this message translates to:
  /// **'Rescan library'**
  String get settingsRescanLibrary;

  /// No description provided for @settingsFolders.
  ///
  /// In en, this message translates to:
  /// **'Music folders'**
  String get settingsFolders;

  /// No description provided for @settingsAddFolder.
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get settingsAddFolder;

  /// No description provided for @settingsRemoveFolder.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get settingsRemoveFolder;

  /// No description provided for @settingsFolderMissing.
  ///
  /// In en, this message translates to:
  /// **'This folder no longer exists'**
  String get settingsFolderMissing;

  /// No description provided for @settingsRemoveFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove folder from library?'**
  String get settingsRemoveFolderTitle;

  /// No description provided for @settingsRemoveFolderBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No songs will leave the library.} =1{1 song will leave the library.} other{{count} songs will leave the library.}} Files on disk are not deleted.'**
  String settingsRemoveFolderBody(int count);

  /// No description provided for @settingsRemoveFolderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get settingsRemoveFolderConfirm;

  /// No description provided for @settingsRemoveFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove {path}. See the log for details.'**
  String settingsRemoveFolderFailed(String path);

  /// No description provided for @settingsRescanOnStartup.
  ///
  /// In en, this message translates to:
  /// **'Rescan when Kanaru opens'**
  String get settingsRescanOnStartup;

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

  /// No description provided for @settingsLibraryStats.
  ///
  /// In en, this message translates to:
  /// **'In your library'**
  String get settingsLibraryStats;

  /// No description provided for @settingsStatsTracks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} track} other{{count} tracks}}'**
  String settingsStatsTracks(int count);

  /// No description provided for @settingsStatsAlbums.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} album} other{{count} albums}}'**
  String settingsStatsAlbums(int count);

  /// No description provided for @settingsStatsArtists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} artist} other{{count} artists}}'**
  String settingsStatsArtists(int count);

  /// No description provided for @settingsStatsGenres.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} genre} other{{count} genres}}'**
  String settingsStatsGenres(int count);

  /// No description provided for @settingsOpenLogFolder.
  ///
  /// In en, this message translates to:
  /// **'Log files'**
  String get settingsOpenLogFolder;

  /// No description provided for @settingsOpenLogFolderHint.
  ///
  /// In en, this message translates to:
  /// **'For bug reports. Passwords and tokens are removed before writing.'**
  String get settingsOpenLogFolderHint;

  /// No description provided for @settingsOpenLogFolderButton.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get settingsOpenLogFolderButton;

  /// No description provided for @settingsLogFolderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Kanaru has no folder for log files on this system.'**
  String get settingsLogFolderUnavailable;

  /// No description provided for @settingsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get settingsComingSoon;

  /// No description provided for @settingsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsOff;

  /// No description provided for @settingsBackupExport.
  ///
  /// In en, this message translates to:
  /// **'Export…'**
  String get settingsBackupExport;

  /// No description provided for @settingsUnitKb.
  ///
  /// In en, this message translates to:
  /// **'{count} KB'**
  String settingsUnitKb(int count);

  /// No description provided for @settingsUnitMb.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String settingsUnitMb(double value);

  /// No description provided for @settingsUnitSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count} s'**
  String settingsUnitSeconds(int count);

  /// No description provided for @settingsUnitMs.
  ///
  /// In en, this message translates to:
  /// **'{count} ms'**
  String settingsUnitMs(int count);

  /// No description provided for @settingsUnitMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String settingsUnitMinutes(int count);

  /// No description provided for @settingsUnitPercent.
  ///
  /// In en, this message translates to:
  /// **'{count}%'**
  String settingsUnitPercent(int count);

  /// No description provided for @settingsAnimations.
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get settingsAnimations;

  /// No description provided for @settingsAnimationsHint.
  ///
  /// In en, this message translates to:
  /// **'Off: pages, panels, tabs and the sidebar change at once, without motion.'**
  String get settingsAnimationsHint;

  /// No description provided for @settingsColorFromCover.
  ///
  /// In en, this message translates to:
  /// **'Colors from the cover'**
  String get settingsColorFromCover;

  /// No description provided for @settingsColorFromCoverHint.
  ///
  /// In en, this message translates to:
  /// **'Tint the app with the colors of the cover that is playing.'**
  String get settingsColorFromCoverHint;

  /// No description provided for @settingsWaveformSeekBar.
  ///
  /// In en, this message translates to:
  /// **'Waveform seek bar'**
  String get settingsWaveformSeekBar;

  /// No description provided for @settingsWaveformSeekBarHint.
  ///
  /// In en, this message translates to:
  /// **'Show the shape of the song in the seek bar of Now Playing.'**
  String get settingsWaveformSeekBarHint;

  /// No description provided for @settingsFontScale.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsFontScale;

  /// No description provided for @settingsFontScaleHint.
  ///
  /// In en, this message translates to:
  /// **'Makes all text in Kanaru smaller or larger.'**
  String get settingsFontScaleHint;

  /// No description provided for @settingsRespectNomedia.
  ///
  /// In en, this message translates to:
  /// **'Skip folders with .nomedia'**
  String get settingsRespectNomedia;

  /// No description provided for @settingsRespectNomediaHint.
  ///
  /// In en, this message translates to:
  /// **'Folders that hold a .nomedia file stay out of the library. Applies at the next rescan.'**
  String get settingsRespectNomediaHint;

  /// No description provided for @settingsSkipHiddenFolders.
  ///
  /// In en, this message translates to:
  /// **'Skip hidden folders'**
  String get settingsSkipHiddenFolders;

  /// No description provided for @settingsSkipHiddenFoldersHint.
  ///
  /// In en, this message translates to:
  /// **'Folders whose name starts with a dot stay out of the library. Applies at the next rescan.'**
  String get settingsSkipHiddenFoldersHint;

  /// No description provided for @settingsDuplicatesByFilename.
  ///
  /// In en, this message translates to:
  /// **'Find duplicates by file name'**
  String get settingsDuplicatesByFilename;

  /// No description provided for @settingsDuplicatesByFilenameHint.
  ///
  /// In en, this message translates to:
  /// **'Files with the same name count as one song. Applies at the next rescan.'**
  String get settingsDuplicatesByFilenameHint;

  /// No description provided for @settingsM3uPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Read m3u playlists'**
  String get settingsM3uPlaylists;

  /// No description provided for @settingsM3uPlaylistsHint.
  ///
  /// In en, this message translates to:
  /// **'Add the .m3u files found in the music folders as playlists. Applies at the next rescan.'**
  String get settingsM3uPlaylistsHint;

  /// No description provided for @settingsAlbumGrouping.
  ///
  /// In en, this message translates to:
  /// **'Group albums by'**
  String get settingsAlbumGrouping;

  /// No description provided for @settingsAlbumGroupingHint.
  ///
  /// In en, this message translates to:
  /// **'Songs with the same album title are one album; pick what else must match. Applies at once, the library updates in the background.'**
  String get settingsAlbumGroupingHint;

  /// No description provided for @settingsAlbumGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Album title'**
  String get settingsAlbumGroupTitle;

  /// No description provided for @settingsAlbumGroupArtist.
  ///
  /// In en, this message translates to:
  /// **'Album artist'**
  String get settingsAlbumGroupArtist;

  /// No description provided for @settingsAlbumGroupYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get settingsAlbumGroupYear;

  /// No description provided for @settingsMinFileSize.
  ///
  /// In en, this message translates to:
  /// **'Minimum file size'**
  String get settingsMinFileSize;

  /// No description provided for @settingsMinFileSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Smaller files stay out of the library. Applies at the next rescan.'**
  String get settingsMinFileSizeHint;

  /// No description provided for @settingsMinDuration.
  ///
  /// In en, this message translates to:
  /// **'Minimum length'**
  String get settingsMinDuration;

  /// No description provided for @settingsMinDurationHint.
  ///
  /// In en, this message translates to:
  /// **'Shorter songs stay out of the library. Applies at the next rescan.'**
  String get settingsMinDurationHint;

  /// No description provided for @settingsClearCoverCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cover cache'**
  String get settingsClearCoverCache;

  /// No description provided for @settingsClearCoverCacheHint.
  ///
  /// In en, this message translates to:
  /// **'Deletes the cover thumbnails; a rescan starts at once and makes them again.'**
  String get settingsClearCoverCacheHint;

  /// No description provided for @settingsClearCoverCacheButton.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsClearCoverCacheButton;

  /// No description provided for @settingsPreferEmbeddedLyrics.
  ///
  /// In en, this message translates to:
  /// **'Prefer embedded lyrics'**
  String get settingsPreferEmbeddedLyrics;

  /// No description provided for @settingsPreferEmbeddedLyricsHint.
  ///
  /// In en, this message translates to:
  /// **'Use lyrics stored in the song file before lyric files next to it.'**
  String get settingsPreferEmbeddedLyricsHint;

  /// No description provided for @settingsGapless.
  ///
  /// In en, this message translates to:
  /// **'Gapless playback'**
  String get settingsGapless;

  /// No description provided for @settingsGaplessHint.
  ///
  /// In en, this message translates to:
  /// **'No silence between songs that follow each other, as on an album.'**
  String get settingsGaplessHint;

  /// No description provided for @settingsCrossfade.
  ///
  /// In en, this message translates to:
  /// **'Crossfade'**
  String get settingsCrossfade;

  /// No description provided for @settingsCrossfadeHint.
  ///
  /// In en, this message translates to:
  /// **'How long the end of a song overlaps the start of the next.'**
  String get settingsCrossfadeHint;

  /// No description provided for @settingsFadeOnPlay.
  ///
  /// In en, this message translates to:
  /// **'Fade in on play'**
  String get settingsFadeOnPlay;

  /// No description provided for @settingsFadeOnPlayHint.
  ///
  /// In en, this message translates to:
  /// **'Raise the volume slowly when playback starts.'**
  String get settingsFadeOnPlayHint;

  /// No description provided for @settingsFadeOnPause.
  ///
  /// In en, this message translates to:
  /// **'Fade out on pause'**
  String get settingsFadeOnPause;

  /// No description provided for @settingsFadeOnPauseHint.
  ///
  /// In en, this message translates to:
  /// **'Lower the volume slowly before playback pauses.'**
  String get settingsFadeOnPauseHint;

  /// No description provided for @settingsInfiniteQueue.
  ///
  /// In en, this message translates to:
  /// **'Endless queue'**
  String get settingsInfiniteQueue;

  /// No description provided for @settingsInfiniteQueueHint.
  ///
  /// In en, this message translates to:
  /// **'Next on the last song goes to the first, and Previous on the first song to the last, whatever the repeat mode.'**
  String get settingsInfiniteQueueHint;

  /// No description provided for @settingsListenAfterTime.
  ///
  /// In en, this message translates to:
  /// **'A listen counts after'**
  String get settingsListenAfterTime;

  /// No description provided for @settingsListenAfterTimeHint.
  ///
  /// In en, this message translates to:
  /// **'This long, or this share of the song, whichever comes first.'**
  String get settingsListenAfterTimeHint;

  /// No description provided for @settingsListenAfterOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get settingsListenAfterOr;

  /// No description provided for @settingsSidebarTabs.
  ///
  /// In en, this message translates to:
  /// **'Sidebar tabs'**
  String get settingsSidebarTabs;

  /// No description provided for @settingsSidebarTabsHint.
  ///
  /// In en, this message translates to:
  /// **'Choose which pages show in the sidebar.'**
  String get settingsSidebarTabsHint;

  /// No description provided for @settingsTabGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get settingsTabGenres;

  /// No description provided for @settingsTabLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get settingsTabLanguages;

  /// No description provided for @settingsTrackNumbers.
  ///
  /// In en, this message translates to:
  /// **'Track numbers in albums'**
  String get settingsTrackNumbers;

  /// No description provided for @settingsTrackNumbersHint.
  ///
  /// In en, this message translates to:
  /// **'Shows each song\'s number before its cover on an album page.'**
  String get settingsTrackNumbersHint;

  /// No description provided for @settingsAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsAdvanced;

  /// No description provided for @settingsBackupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore'**
  String get settingsBackupRestore;

  /// No description provided for @settingsBackupRestoreRow.
  ///
  /// In en, this message translates to:
  /// **'Back up and restore data'**
  String get settingsBackupRestoreRow;

  /// No description provided for @settingsBackupRestoreHint.
  ///
  /// In en, this message translates to:
  /// **'Export and import your settings, playlists and play counts.'**
  String get settingsBackupRestoreHint;

  /// No description provided for @settingsThemeHint.
  ///
  /// In en, this message translates to:
  /// **'Light, dark, or follow the desktop'**
  String get settingsThemeHint;

  /// No description provided for @settingsLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Language of menus and labels'**
  String get settingsLanguageHint;

  /// No description provided for @settingsTitleBarHint.
  ///
  /// In en, this message translates to:
  /// **'Kanaru\'s own bar with window buttons, the system\'s, or none'**
  String get settingsTitleBarHint;

  /// No description provided for @settingsFoldersHint.
  ///
  /// In en, this message translates to:
  /// **'Folders Kanaru looks for music in. Removing one never deletes files.'**
  String get settingsFoldersHint;

  /// No description provided for @settingsRescanOnStartupHint.
  ///
  /// In en, this message translates to:
  /// **'Look for new, changed and removed files in the background each time Kanaru opens'**
  String get settingsRescanOnStartupHint;

  /// No description provided for @settingsRescanLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Look for changes in the music folders now'**
  String get settingsRescanLibraryHint;

  /// No description provided for @settingsClearListenHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Removes every recorded listen on this device. Can\'t be undone.'**
  String get settingsClearListenHistoryHint;

  /// No description provided for @listenHistoryRecord.
  ///
  /// In en, this message translates to:
  /// **'Record listen history'**
  String get listenHistoryRecord;

  /// No description provided for @listenHistoryRecordHint.
  ///
  /// In en, this message translates to:
  /// **'Kept only on this device. Turning it off keeps what is already recorded.'**
  String get listenHistoryRecordHint;

  /// No description provided for @listenHistoryClear.
  ///
  /// In en, this message translates to:
  /// **'Clear listen history'**
  String get listenHistoryClear;

  /// No description provided for @listenHistoryClearButton.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get listenHistoryClearButton;

  /// No description provided for @listenHistoryClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all listen history?'**
  String get listenHistoryClearTitle;

  /// No description provided for @listenHistoryClearBody.
  ///
  /// In en, this message translates to:
  /// **'Every recorded listen, with play counts and last-played times, is removed from Kanaru. This cannot be undone.'**
  String get listenHistoryClearBody;

  /// No description provided for @listenHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Listen history cleared} =1{Listen history cleared (1 listen)} other{Listen history cleared ({count} listens)}}'**
  String listenHistoryCleared(int count);

  /// No description provided for @listenHistoryClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear listen history'**
  String get listenHistoryClearFailed;

  /// No description provided for @playbackUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio engine not found'**
  String get playbackUnavailableTitle;

  /// No description provided for @playbackUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'libmpv could not be loaded. You can browse your library, but playback is turned off.'**
  String get playbackUnavailableBody;

  /// No description provided for @settingsAudioOutputDevice.
  ///
  /// In en, this message translates to:
  /// **'Output device'**
  String get settingsAudioOutputDevice;

  /// No description provided for @audioDeviceAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic (system default)'**
  String get audioDeviceAuto;

  /// No description provided for @audioDeviceMissing.
  ///
  /// In en, this message translates to:
  /// **'{name} — not available, using Automatic'**
  String audioDeviceMissing(String name);

  /// No description provided for @audioDeviceDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Output device'**
  String get audioDeviceDialogTitle;

  /// No description provided for @audioDeviceNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No other output devices found'**
  String get audioDeviceNoneFound;

  /// No description provided for @audioDeviceOtherOutputs.
  ///
  /// In en, this message translates to:
  /// **'Other outputs'**
  String get audioDeviceOtherOutputs;

  /// No description provided for @audioDeviceFailed.
  ///
  /// In en, this message translates to:
  /// **'{name} — could not be opened, using Automatic'**
  String audioDeviceFailed(String name);

  /// No description provided for @audioDeviceChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get audioDeviceChange;

  /// No description provided for @settingsAudioReplayGain.
  ///
  /// In en, this message translates to:
  /// **'ReplayGain'**
  String get settingsAudioReplayGain;

  /// No description provided for @settingsAudioReplayGainHint.
  ///
  /// In en, this message translates to:
  /// **'Evens out loudness with the ReplayGain tags in your files. Automatic uses album gain while tracks of one album play in a row, and track gain otherwise.'**
  String get settingsAudioReplayGainHint;

  /// No description provided for @replayGainModeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get replayGainModeOff;

  /// No description provided for @replayGainModeTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get replayGainModeTrack;

  /// No description provided for @replayGainModeAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get replayGainModeAlbum;

  /// No description provided for @replayGainModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get replayGainModeAuto;

  /// No description provided for @settingsAudioReplayGainPreamp.
  ///
  /// In en, this message translates to:
  /// **'ReplayGain preamp'**
  String get settingsAudioReplayGainPreamp;

  /// No description provided for @settingsAudioReplayGainPreampHint.
  ///
  /// In en, this message translates to:
  /// **'Gain added on top of the ReplayGain value. Files without ReplayGain tags keep their level.'**
  String get settingsAudioReplayGainPreampHint;

  /// No description provided for @settingsAudioDecibels.
  ///
  /// In en, this message translates to:
  /// **'{value} dB'**
  String settingsAudioDecibels(String value);

  /// No description provided for @settingsAudioPreventClipping.
  ///
  /// In en, this message translates to:
  /// **'Prevent clipping'**
  String get settingsAudioPreventClipping;

  /// No description provided for @settingsAudioPreventClippingHint.
  ///
  /// In en, this message translates to:
  /// **'Lower the gain when a boost would distort the loudest peaks.'**
  String get settingsAudioPreventClippingHint;

  /// Title of the excluded folders setting
  ///
  /// In en, this message translates to:
  /// **'Excluded folders'**
  String get excludedFoldersTitle;

  /// Explains what excluding a folder does
  ///
  /// In en, this message translates to:
  /// **'Folders inside your music folders that Kanaru skips. Songs in them leave the library. Files are never deleted.'**
  String get excludedFoldersHint;

  /// Button that picks a folder to exclude
  ///
  /// In en, this message translates to:
  /// **'Exclude folder'**
  String get excludedFoldersAdd;

  /// Tooltip of the button that stops excluding a folder
  ///
  /// In en, this message translates to:
  /// **'Stop excluding'**
  String get excludedFoldersRemove;

  /// Note on an excluded folder that is not below any library folder
  ///
  /// In en, this message translates to:
  /// **'Not inside a music folder, so it has no effect'**
  String get excludedFoldersNotInLibrary;

  /// Note on an excluded folder that no longer exists
  ///
  /// In en, this message translates to:
  /// **'Folder not found'**
  String get excludedFoldersMissing;

  /// Shown when the folder to exclude is a library folder
  ///
  /// In en, this message translates to:
  /// **'That is a music folder. Remove it from the folders above instead.'**
  String get excludedFoldersSameAsRoot;

  /// Shown when the folder to exclude is not below a library folder
  ///
  /// In en, this message translates to:
  /// **'That folder is not inside a music folder.'**
  String get excludedFoldersOutsideLibrary;

  /// Shown when the folder is already excluded
  ///
  /// In en, this message translates to:
  /// **'That folder is already excluded.'**
  String get excludedFoldersAlreadyExcluded;

  /// Title of the switch that makes Kanaru rescan by itself when files in the music folders change
  ///
  /// In en, this message translates to:
  /// **'Watch music folders'**
  String get settingsWatchFolders;

  /// Subtitle of the watch music folders switch
  ///
  /// In en, this message translates to:
  /// **'Pick up added, changed and removed files while Kanaru runs, a few seconds after they stop changing'**
  String get settingsWatchFoldersHint;

  /// Subtitle of the watch switch when the system limit of watches ran out (Linux inotify)
  ///
  /// In en, this message translates to:
  /// **'Too many folders to watch on this system. Raise fs.inotify.max_user_watches, or use Rescan.'**
  String get settingsWatchFoldersLimit;

  /// Message of the History page when nothing was played yet
  ///
  /// In en, this message translates to:
  /// **'Songs you play will show up here.'**
  String get historyEmptyMessage;

  /// Date on the bar that starts a History day
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String historyDayDate(DateTime date);

  /// After the listen count on the History page: the date of the first play
  ///
  /// In en, this message translates to:
  /// **'since {date}'**
  String historySince(DateTime date);

  /// Third line of a History row: the day and time the song was played
  ///
  /// In en, this message translates to:
  /// **'{date} - {time}'**
  String historyPlayedAt(DateTime date, String time);

  /// Tooltip of the menu button on a History day bar
  ///
  /// In en, this message translates to:
  /// **'Day options'**
  String get historyDayMenu;

  /// Menu item that saves the songs of a History day as a playlist
  ///
  /// In en, this message translates to:
  /// **'Create playlist from this day'**
  String get historyDayCreatePlaylist;

  /// Menu item that removes every listen shown for a History day
  ///
  /// In en, this message translates to:
  /// **'Remove this day\'s listens'**
  String get historyDayDelete;

  /// Suggested name of a playlist made from a History day
  ///
  /// In en, this message translates to:
  /// **'History · {date}'**
  String historyDayPlaylistName(DateTime date);

  /// How many plays a History day holds
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 listen} other{{count} listens}}'**
  String historyListenCount(int count);

  /// Badge on a History row: this is the Nth time the song was played
  ///
  /// In en, this message translates to:
  /// **'#{n}'**
  String historyNthPlay(int n);

  /// Tooltip and screen reader text of the Nth play badge
  ///
  /// In en, this message translates to:
  /// **'Listen number {n}'**
  String historyNthPlayLabel(int n);

  /// Note on a History row whose file is no longer in the library
  ///
  /// In en, this message translates to:
  /// **'Not in library'**
  String get historyTrackMissing;

  /// Menu item that removes one play from the History
  ///
  /// In en, this message translates to:
  /// **'Remove from history'**
  String get historyDeletePlay;

  /// Snackbar after plays were removed from the History
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Removed one listen from history} other{Removed {count} listens from history}}'**
  String historyPlaysDeleted(int count);

  /// Snackbar action that puts a removed play back
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get historyUndo;

  /// Snackbar when removing a play failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove the listen. See the log for details.'**
  String get historyDeleteFailed;

  /// Snackbar when undoing a removal failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore the listen. See the log for details.'**
  String get historyRestoreFailed;

  /// Tooltip of the button that opens the History calendar
  ///
  /// In en, this message translates to:
  /// **'Jump to a day'**
  String get historyCalendar;

  /// Note on the empty History page when recording is off in Settings
  ///
  /// In en, this message translates to:
  /// **'Recording listen history is turned off'**
  String get historyRecordingOff;

  /// Title of the History page when there is no library database
  ///
  /// In en, this message translates to:
  /// **'History is not available'**
  String get historyUnavailable;

  /// Message of the History page when reading it failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the history. See the log for details.'**
  String get historyLoadFailed;

  /// Tooltip of the more button on a History row
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get historyMore;

  /// Last row of the History list: switches to an older year
  ///
  /// In en, this message translates to:
  /// **'Show {year}'**
  String historyOlderYear(int year);

  /// Most played range chip and label for the current day
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historyRangeToday;

  /// Most played range chip: the last 7 days
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get historyRange7Days;

  /// Most played range chip: the last 30 days
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get historyRange30Days;

  /// Most played range chip: the last 6 months
  ///
  /// In en, this message translates to:
  /// **'6 months'**
  String get historyRange6Months;

  /// Most played range chip: the last 12 months
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get historyRangeYear;

  /// Most played range chip and label for the whole history
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get historyRangeAll;

  /// Most played range chip that opens the date range picker
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get historyRangeCustom;

  /// Tooltip of the button that moves the Most played range back
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get historyRangePrevious;

  /// Tooltip of the button that moves the Most played range forward
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get historyRangeNext;

  /// Caption above the days picked in the Most played custom range dialog
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get historyRangeDialogTitle;

  /// Hint in the custom range dialog before the first day is picked
  ///
  /// In en, this message translates to:
  /// **'Pick the start date'**
  String get historyRangePickStart;

  /// Hint in the custom range dialog after the first day is picked
  ///
  /// In en, this message translates to:
  /// **'Pick the end date'**
  String get historyRangePickEnd;

  /// Days picked, shown as the hint of the custom range dialog
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String historyRangeDays(int count);

  /// Screen reader cue on a day of the custom range calendar that holds plays
  ///
  /// In en, this message translates to:
  /// **'Has listens'**
  String get historyRangeDayHasListens;

  /// Shown in the custom range dialog title until the first day is picked
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get historyRangeStartPlaceholder;

  /// Shown in the custom range dialog title until the last day is picked
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get historyRangeEndPlaceholder;

  /// First and last day of the Most played range
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String historyRangeLabel(String start, String end);

  /// Plays of a song on a Most played row
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 listen} other{{count} listens}}'**
  String historyTopPlayCount(int count);

  /// Note under the Most played list when it was cut at its limit
  ///
  /// In en, this message translates to:
  /// **'Showing first {count}'**
  String historyTopCapped(int count);

  /// Button that plays the Most played list from the top
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get historyPlayAll;

  /// Button that saves the Most played list as a playlist
  ///
  /// In en, this message translates to:
  /// **'Create playlist'**
  String get historyCreatePlaylist;

  /// Suggested name of a playlist made from the Most played list
  ///
  /// In en, this message translates to:
  /// **'Most played · {range}'**
  String historyTopPlaylistName(String range);

  /// Snackbar after a playlist was made from the Most played list
  ///
  /// In en, this message translates to:
  /// **'Created playlist {name}'**
  String historyPlaylistCreated(String name);

  /// Message of the Most played page when the range has no plays
  ///
  /// In en, this message translates to:
  /// **'No listens in this range'**
  String get historyTopEmpty;

  /// Row menu item that opens the history page of a song
  ///
  /// In en, this message translates to:
  /// **'Song history'**
  String get historyShowTrackHistory;

  /// Title of the song history page when no song is named
  ///
  /// In en, this message translates to:
  /// **'Song history'**
  String get historyTrackTitle;

  /// Number of plays of a song in the header of its history page
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 listen} other{{count} listens}}'**
  String historyTrackStats(int count);

  /// Day of the first play in the header of a song history page
  ///
  /// In en, this message translates to:
  /// **'First {date}'**
  String historyTrackFirst(String date);

  /// Day and time of the latest play in the header of a song history page
  ///
  /// In en, this message translates to:
  /// **'Last {date}'**
  String historyTrackLast(String date);

  /// How long a play was listened to, on a row of the song history page
  ///
  /// In en, this message translates to:
  /// **'listened {duration}'**
  String historyListened(String duration);

  /// Message of the song history page when the song has no plays
  ///
  /// In en, this message translates to:
  /// **'No listens yet'**
  String get historyTrackNoPlays;

  /// Message of the song history page opened without a song
  ///
  /// In en, this message translates to:
  /// **'Song not found'**
  String get historyTrackNotFound;

  /// Button on the song history page that plays the song
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get historyPlay;

  /// Tooltip of the filled heart and song menu item that take a song out of Favorites
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get favoritesRemove;

  /// Snackbar after liking a song from its menu
  ///
  /// In en, this message translates to:
  /// **'Added to Favorites'**
  String get favoritesAdded;

  /// Snackbar after unliking a song from its menu
  ///
  /// In en, this message translates to:
  /// **'Removed from Favorites'**
  String get favoritesRemoved;

  /// Button on the playlists page that imports an M3U playlist file
  ///
  /// In en, this message translates to:
  /// **'Import M3U…'**
  String get playlistM3uImport;

  /// File type filter of the M3U file picker that shows every file
  ///
  /// In en, this message translates to:
  /// **'All files'**
  String get playlistM3uAllFiles;

  /// Progress dialog while an M3U file is imported
  ///
  /// In en, this message translates to:
  /// **'Importing playlist…'**
  String get playlistM3uImporting;

  /// Snackbar after a clean M3U import
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 song into {name}} other{Imported {count} songs into {name}}}'**
  String playlistM3uImported(int count, String name);

  /// Added after the import snackbar when some imported files are not library songs yet
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 is not in your library yet} other{{count} are not in your library yet}}'**
  String playlistM3uImportedNotInLibrary(int count);

  /// Title of the dialog that reports an M3U import
  ///
  /// In en, this message translates to:
  /// **'Playlist imported'**
  String get playlistM3uImportReportTitle;

  /// First line of the M3U import report
  ///
  /// In en, this message translates to:
  /// **'Added {added} of {total} lines.'**
  String playlistM3uImportReportSummary(int added, int total);

  /// M3U import report: files that exist but are not library songs
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song is not in your library yet: it shows once its folder is added.} other{{count} songs are not in your library yet: they show once their folder is added.}}'**
  String playlistM3uImportReportNotInLibrary(int count);

  /// M3U import report: lines naming a file already imported
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 repeated line was merged.} other{{count} repeated lines were merged.}}'**
  String playlistM3uImportReportDuplicates(int count);

  /// M3U import report: heading of the lines that could not be used
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line is not a local music file or was not found:} other{{count} lines are not local music files or were not found:}}'**
  String playlistM3uImportReportUnresolved(int count);

  /// M3U import report: the file had more lines than the limit
  ///
  /// In en, this message translates to:
  /// **'Only the first {limit} songs were read.'**
  String playlistM3uImportReportTruncated(int limit);

  /// M3U import report: one unused line with its line number
  ///
  /// In en, this message translates to:
  /// **'Line {line}: {text}'**
  String playlistM3uImportReportLine(int line, String text);

  /// M3U import report: unused lines not listed
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{and 1 more line} other{and {count} more lines}}'**
  String playlistM3uImportReportMore(int count);

  /// M3U import report when no line could be used
  ///
  /// In en, this message translates to:
  /// **'No local music file of this playlist was found. Nothing was imported.'**
  String get playlistM3uImportNothingFound;

  /// Snackbar when the picked M3U file is over the size limit
  ///
  /// In en, this message translates to:
  /// **'That file is too large to be a playlist.'**
  String get playlistM3uImportTooLarge;

  /// Snackbar when the picked M3U file cannot be read
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read that playlist file. See the log for details.'**
  String get playlistM3uImportFailed;

  /// Playlist menu item: save as M3U with absolute paths
  ///
  /// In en, this message translates to:
  /// **'Export M3U (full paths)…'**
  String get playlistM3uExportAbsolute;

  /// Playlist menu item: save as M3U with paths relative to the file
  ///
  /// In en, this message translates to:
  /// **'Export M3U (relative paths)…'**
  String get playlistM3uExportRelative;

  /// Snackbar after exporting a playlist
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Saved 1 song to {file}} other{Saved {count} songs to {file}}}'**
  String playlistM3uExported(int count, String file);

  /// Added to the export snackbar when some paths cannot be written as M3U lines
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 path with a line break was left out} other{{count} paths with line breaks were left out}}'**
  String playlistM3uExportSkipped(int count);

  /// Snackbar when writing the M3U file failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the playlist file. See the log for details.'**
  String get playlistM3uExportFailed;

  /// Title of the dialog asking before overwriting an existing file
  ///
  /// In en, this message translates to:
  /// **'Replace {file}?'**
  String playlistM3uOverwriteTitle(String file);

  /// Button that overwrites the existing file
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get playlistM3uOverwriteConfirm;

  /// Tooltip of the queue panel button that saves the queue as a new playlist
  ///
  /// In en, this message translates to:
  /// **'Save queue as playlist'**
  String get queueSaveAsPlaylist;

  /// Default name of a playlist saved from the queue
  ///
  /// In en, this message translates to:
  /// **'Queue {date}'**
  String queueSaveDefaultName(DateTime date);

  /// Snackbar after saving the queue as a playlist
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Saved 1 song to {name}} other{Saved {count} songs to {name}}}'**
  String queueSaved(int count, String name);

  /// Snackbar after saving the queue when some queue songs were not saved
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Saved 1 song to {name}} other{Saved {count} songs to {name}}}, {skipped, plural, =1{1 left out (not in your library or repeated)} other{{skipped} left out (not in your library or repeated)}}'**
  String queueSavedSkipped(int count, int skipped, String name);

  /// Snackbar when no queue song can be saved in a playlist
  ///
  /// In en, this message translates to:
  /// **'Nothing in the queue is in your library'**
  String get queueSaveNothing;

  /// Name of the page listing the queues the user replaced, in the sidebar and as its title
  ///
  /// In en, this message translates to:
  /// **'Queues'**
  String get queueHistoryTitle;

  /// Title on the queue history page before any queue was replaced
  ///
  /// In en, this message translates to:
  /// **'No queue history yet'**
  String get queueHistoryEmptyTitle;

  /// Message on the empty queue history page
  ///
  /// In en, this message translates to:
  /// **'When you play something new, the queue it replaces is kept here.'**
  String get queueHistoryEmptyMessage;

  /// Name of a saved queue: when it was saved
  ///
  /// In en, this message translates to:
  /// **'{date} · {time}'**
  String queueHistorySavedAt(DateTime date, DateTime time);

  /// Menu row and button that play a saved queue
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get queueHistoryPlay;

  /// Menu row that plays a saved queue shuffled
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get queueHistoryShuffle;

  /// Menu row that copies a saved queue into a new playlist
  ///
  /// In en, this message translates to:
  /// **'Save as playlist'**
  String get queueHistorySaveAsPlaylist;

  /// Snackbar after a saved queue was copied into a new playlist
  ///
  /// In en, this message translates to:
  /// **'Saved as {name}'**
  String queueHistorySavedAsPlaylist(String name);

  /// Menu row and dialog button that delete a saved queue
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get queueHistoryDelete;

  /// Title of the dialog confirming that a saved queue is deleted
  ///
  /// In en, this message translates to:
  /// **'Delete this queue?'**
  String get queueHistoryDeleteTitle;

  /// Body of the dialog confirming that a saved queue is deleted
  ///
  /// In en, this message translates to:
  /// **'It is removed from your queue history. The songs stay in your library.'**
  String get queueHistoryDeleteMessage;

  /// Snackbar after a saved queue was deleted
  ///
  /// In en, this message translates to:
  /// **'Queue deleted'**
  String get queueHistoryDeleted;

  /// Snackbar when a saved queue has no song that can play
  ///
  /// In en, this message translates to:
  /// **'None of these songs are in your library'**
  String get queueHistoryNothingToPlay;

  /// Name of the lyrics page of the narrow Now Playing layout
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyricsTab;

  /// Title of the dialog that confirms deleting the cover thumbnails
  ///
  /// In en, this message translates to:
  /// **'Clear the cover cache?'**
  String get coverCacheClearTitle;

  /// Body of the dialog that confirms deleting the cover thumbnails
  ///
  /// In en, this message translates to:
  /// **'Every cover disappears from the library until it is made again. Kanaru rescans right away and makes them in the background, which can take a while for a large library. Colors taken from the covers are kept.'**
  String get coverCacheClearBody;

  /// Snackbar after the cover thumbnails were deleted
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Deleted 1 cover. A rescan makes them again.} other{Deleted {count} covers. A rescan makes them again.}}'**
  String coverCacheCleared(int count);

  /// Snackbar when the cover thumbnails could not be deleted
  ///
  /// In en, this message translates to:
  /// **'Could not clear the cover cache'**
  String get coverCacheClearFailed;

  /// Name of the Genres entry that holds songs with no genre tag, always last in the list
  ///
  /// In en, this message translates to:
  /// **'Unknown genre'**
  String get genresUnknown;

  /// Title of the settings row and dialog that edit how artist tags are split
  ///
  /// In en, this message translates to:
  /// **'Split artists'**
  String get separatorsArtistsTitle;

  /// Title of the settings row and dialog that edit how genre tags are split
  ///
  /// In en, this message translates to:
  /// **'Split genres'**
  String get separatorsGenresTitle;

  /// Subtitle of the artist split row, first line
  ///
  /// In en, this message translates to:
  /// **'Applies at once, the library updates in the background.'**
  String get separatorsArtistsHint;

  /// Subtitle of the genre split row, first line
  ///
  /// In en, this message translates to:
  /// **'Applies at once, no rescan needed.'**
  String get separatorsGenresHint;

  /// Second line of a split row: how many separators and keep-whole names are set
  ///
  /// In en, this message translates to:
  /// **'{separators, plural, =1{1 separator} other{{separators} separators}} · {keepWhole, plural, =1{1 kept whole} other{{keepWhole} kept whole}}'**
  String separatorsSummary(int separators, int keepWhole);

  /// Button of a split row that opens its dialog
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get separatorsEditButton;

  /// Dialog tab listing the separators, with how many there are
  ///
  /// In en, this message translates to:
  /// **'Separators ({count})'**
  String separatorsTabSeparators(int count);

  /// Dialog tab listing names that are never split, with how many there are
  ///
  /// In en, this message translates to:
  /// **'Keep whole ({count})'**
  String separatorsTabKeepWhole(int count);

  /// Label of the field that adds a separator
  ///
  /// In en, this message translates to:
  /// **'New separator'**
  String get separatorsAddSeparatorLabel;

  /// Label of the field that adds a name that is never split
  ///
  /// In en, this message translates to:
  /// **'Name to keep whole'**
  String get separatorsAddKeepLabel;

  /// Help under the separator field
  ///
  /// In en, this message translates to:
  /// **'No need to add spaces around it. Words like feat. split only with a space on each side.'**
  String get separatorsSeparatorHelp;

  /// Help under the keep-whole field of the artist dialog
  ///
  /// In en, this message translates to:
  /// **'Type the name as it is in the tag, any case. AC/DC, for example, stays one artist.'**
  String get separatorsKeepHelpArtist;

  /// Help under the keep-whole field of the genre dialog
  ///
  /// In en, this message translates to:
  /// **'Type the name as it is in the tag, any case. Funk/Soul, for example, stays one genre.'**
  String get separatorsKeepHelpGenre;

  /// Button that adds the typed entry
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get separatorsAdd;

  /// Error under the field when nothing was typed
  ///
  /// In en, this message translates to:
  /// **'Type something to add'**
  String get separatorsErrorEmpty;

  /// Error under the field when the entry is in the list already, in any case
  ///
  /// In en, this message translates to:
  /// **'Already in the list'**
  String get separatorsErrorDuplicate;

  /// Error under the field when the entry is too long
  ///
  /// In en, this message translates to:
  /// **'At most {max} characters'**
  String separatorsErrorTooLong(int max);

  /// Error under the field when the list is full
  ///
  /// In en, this message translates to:
  /// **'The list holds at most {max} entries'**
  String separatorsErrorFull(int max);

  /// Tooltip of the button that removes an entry
  ///
  /// In en, this message translates to:
  /// **'Remove {entry}'**
  String separatorsRemove(String entry);

  /// Shown in place of an empty list
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get separatorsEmptyList;

  /// Shown in place of an empty separator list
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet, so nothing is split'**
  String get separatorsEmptySeparators;

  /// Tooltip of a page dot below a long list
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String separatorsPage(int page, int total);

  /// Button that puts both lists of the dialog back to their defaults
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get separatorsReset;

  /// Title of the confirmation before restoring the defaults
  ///
  /// In en, this message translates to:
  /// **'Restore defaults?'**
  String get separatorsResetConfirmTitle;

  /// Body of the confirmation before restoring the defaults
  ///
  /// In en, this message translates to:
  /// **'Both lists go back to their defaults.'**
  String get separatorsResetConfirmBody;

  /// Button that confirms restoring the defaults
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get separatorsResetConfirm;

  /// Button that closes the dialog
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get separatorsClose;

  /// Title of the scan statistics row with the songs found and the music files seen
  ///
  /// In en, this message translates to:
  /// **'Songs in the library'**
  String get scanStatsTracksTitle;

  /// Songs stored out of the music files the last scan of this session saw
  ///
  /// In en, this message translates to:
  /// **'{tracks} of {files} music files'**
  String scanStatsTracksOfFiles(int tracks, int files);

  /// Shown instead of the numbers only a scan knows, until the first scan of the session ends
  ///
  /// In en, this message translates to:
  /// **'Not scanned in this session'**
  String get scanStatsNotScanned;

  /// Title of the scan statistics row with the files the scan rules left out
  ///
  /// In en, this message translates to:
  /// **'Left out by scan rules'**
  String get scanStatsLeftOutTitle;

  /// Files left out for being in a folder that holds a .nomedia entry
  ///
  /// In en, this message translates to:
  /// **'In .nomedia folders: {count, plural, =1{1 file} other{{count} files}}'**
  String scanStatsNomedia(int count);

  /// Files left out for being in a folder the user left out
  ///
  /// In en, this message translates to:
  /// **'In left-out folders: {count, plural, =1{1 file} other{{count} files}}'**
  String scanStatsExcluded(int count);

  /// Files left out for being smaller than the minimum file size
  ///
  /// In en, this message translates to:
  /// **'Under minimum size: {count, plural, =1{1 file} other{{count} files}}'**
  String scanStatsTooSmall(int count);

  /// Files left out for being shorter than the minimum length
  ///
  /// In en, this message translates to:
  /// **'Under minimum length: {count, plural, =1{1 file} other{{count} files}}'**
  String scanStatsTooShort(int count);

  /// Title of the scan statistics row with the songs whose tags could not be read
  ///
  /// In en, this message translates to:
  /// **'Tag errors'**
  String get scanStatsTagErrorsTitle;

  /// Songs stored without tags because reading them failed
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No songs} =1{1 song} other{{count} songs}} stored without readable tags'**
  String scanStatsTagErrors(int count);

  /// Title of the scan statistics row with the cover art made
  ///
  /// In en, this message translates to:
  /// **'Cover art'**
  String get scanStatsCoversTitle;

  /// Distinct cover thumbnails, and the songs that have one
  ///
  /// In en, this message translates to:
  /// **'{images} images made for {tracks} songs with art'**
  String scanStatsCovers(int images, int tracks);

  /// Songs stored, before the first scan of the session
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}}'**
  String scanStatsSongs(int count);

  /// Note under the songs row: folders the last scan skipped (missing, timed out), whose files the numbers leave out
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 folder not scanned to the end} other{{count} folders not scanned to the end}}'**
  String scanStatsUnfinishedRoots(int count);

  /// Note under the cover art numbers
  ///
  /// In en, this message translates to:
  /// **'Kanaru makes these thumbnails itself from the art in the files or the folder. An image repeated in many songs is stored once (by hash).'**
  String get scanStatsCoversHint;

  /// Tooltip of the eye button on the Folders pages while hidden folders and files are not shown
  ///
  /// In en, this message translates to:
  /// **'Show hidden items'**
  String get foldersHiddenShow;

  /// Tooltip of the eye button on the Folders pages while hidden folders and files are shown
  ///
  /// In en, this message translates to:
  /// **'Hide hidden items'**
  String get foldersHiddenHide;

  /// Small label on a folder or song whose name starts with a dot, shown when hidden items are on
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get foldersHiddenLabel;

  /// Tooltip and menu title of the moon button that pauses playback later
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// Tooltip and screen reader label of the moon button while the timer runs; state is the time left or the mode
  ///
  /// In en, this message translates to:
  /// **'Sleep timer: {state}'**
  String sleepTimerActive(String state);

  /// Preset in the sleep timer menu
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String sleepTimerMinutes(int count);

  /// Sleep timer menu item that asks for a number of minutes
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get sleepTimerCustom;

  /// Sleep timer mode: pause when the current track ends
  ///
  /// In en, this message translates to:
  /// **'End of track'**
  String get sleepTimerEndOfTrack;

  /// Sleep timer mode: pause when the album ends
  ///
  /// In en, this message translates to:
  /// **'End of album'**
  String get sleepTimerEndOfAlbum;

  /// Sleep timer mode: pause when the last track of the queue ends
  ///
  /// In en, this message translates to:
  /// **'End of queue'**
  String get sleepTimerEndOfQueue;

  /// Header of the sleep timer menu while counting minutes
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String sleepTimerLeft(String time);

  /// Header of the sleep timer menu while the countdown is on hold
  ///
  /// In en, this message translates to:
  /// **'{time} left (paused)'**
  String sleepTimerLeftPaused(String time);

  /// Sleep timer menu item
  ///
  /// In en, this message translates to:
  /// **'Add 5 minutes'**
  String get sleepTimerAdd;

  /// Sleep timer menu item
  ///
  /// In en, this message translates to:
  /// **'Remove 5 minutes'**
  String get sleepTimerSubtract;

  /// Sleep timer menu item that holds the countdown
  ///
  /// In en, this message translates to:
  /// **'Pause counting'**
  String get sleepTimerPauseCounting;

  /// Sleep timer menu item that continues a held countdown
  ///
  /// In en, this message translates to:
  /// **'Resume counting'**
  String get sleepTimerResumeCounting;

  /// Sleep timer menu item that turns the timer off
  ///
  /// In en, this message translates to:
  /// **'Cancel timer'**
  String get sleepTimerCancel;

  /// Title of the dialog that asks for minutes
  ///
  /// In en, this message translates to:
  /// **'Custom sleep timer'**
  String get sleepTimerCustomTitle;

  /// Field label in the custom sleep timer dialog
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get sleepTimerCustomLabel;

  /// Validation message in the custom sleep timer dialog
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from {min} to {max}'**
  String sleepTimerCustomInvalid(int min, int max);

  /// Button of the custom sleep timer dialog
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get sleepTimerStart;

  /// Short label beside the moon button while the timer waits for the end of the track
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get sleepTimerLabelTrack;

  /// Short label beside the moon button while the timer waits for the end of the album
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get sleepTimerLabelAlbum;

  /// Short label beside the moon button while the timer waits for the end of the queue
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get sleepTimerLabelQueue;

  /// Sidebar and page title for song languages
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get navLanguages;

  /// Title of the empty Languages page
  ///
  /// In en, this message translates to:
  /// **'Languages are coming soon'**
  String get languagesComingSoonTitle;

  /// Message of the empty Languages page
  ///
  /// In en, this message translates to:
  /// **'Browsing songs by language is not available yet.'**
  String get languagesComingSoonMessage;

  /// Name of the language with ISO 639-2 code eng
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEng;

  /// Name of the language with ISO 639-2 code vie
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get languageNameVie;

  /// Name of the language with ISO 639-2 code jpn
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageNameJpn;

  /// Name of the language with ISO 639-2 code kor
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageNameKor;

  /// Name of the language with ISO 639-2 code zho
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageNameZho;

  /// Name of the language with ISO 639-2 code fra
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageNameFra;

  /// Name of the language with ISO 639-2 code deu
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageNameDeu;

  /// Name of the language with ISO 639-2 code spa
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageNameSpa;

  /// Name of the language with ISO 639-2 code ita
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get languageNameIta;

  /// Name of the language with ISO 639-2 code rus
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageNameRus;

  /// Name of the language with ISO 639-2 code por
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languageNamePor;

  /// Name of the language with ISO 639-2 code tha
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get languageNameTha;

  /// Name of the language with ISO 639-2 code ind
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get languageNameInd;

  /// Name of the language with ISO 639-2 code hin
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageNameHin;

  /// Name of the language with ISO 639-2 code ara
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageNameAra;

  /// Name of the language with ISO 639-2 code nld
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get languageNameNld;

  /// Name of the language with ISO 639-2 code swe
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get languageNameSwe;

  /// Name of the language with ISO 639-2 code pol
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get languageNamePol;

  /// Name of the language with ISO 639-2 code tur
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get languageNameTur;

  /// Name of the language with ISO 639-2 code ukr
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get languageNameUkr;

  /// Name of the language with ISO 639-2 code ces
  ///
  /// In en, this message translates to:
  /// **'Czech'**
  String get languageNameCes;

  /// Name of the language with ISO 639-2 code ell
  ///
  /// In en, this message translates to:
  /// **'Greek'**
  String get languageNameEll;

  /// Name of the language with ISO 639-2 code fas
  ///
  /// In en, this message translates to:
  /// **'Persian'**
  String get languageNameFas;

  /// Name of the language with ISO 639-2 code ron
  ///
  /// In en, this message translates to:
  /// **'Romanian'**
  String get languageNameRon;

  /// Name of the language with ISO 639-2 code msa
  ///
  /// In en, this message translates to:
  /// **'Malay'**
  String get languageNameMsa;

  /// Name of the language with ISO 639-2 code heb
  ///
  /// In en, this message translates to:
  /// **'Hebrew'**
  String get languageNameHeb;

  /// Name of the language with ISO 639-2 code fin
  ///
  /// In en, this message translates to:
  /// **'Finnish'**
  String get languageNameFin;

  /// Name of the language with ISO 639-2 code dan
  ///
  /// In en, this message translates to:
  /// **'Danish'**
  String get languageNameDan;

  /// Name of the language with ISO 639-2 code nor
  ///
  /// In en, this message translates to:
  /// **'Norwegian'**
  String get languageNameNor;

  /// Name of the language with ISO 639-2 code hun
  ///
  /// In en, this message translates to:
  /// **'Hungarian'**
  String get languageNameHun;

  /// Name of the language with ISO 639-2 code cym
  ///
  /// In en, this message translates to:
  /// **'Welsh'**
  String get languageNameCym;

  /// Name of the language with ISO 639-2 code slk
  ///
  /// In en, this message translates to:
  /// **'Slovak'**
  String get languageNameSlk;

  /// Name of the language with ISO 639-2 code sqi
  ///
  /// In en, this message translates to:
  /// **'Albanian'**
  String get languageNameSqi;

  /// Name of the language with ISO 639-2 code hye
  ///
  /// In en, this message translates to:
  /// **'Armenian'**
  String get languageNameHye;

  /// Name of the language with ISO 639-2 code eus
  ///
  /// In en, this message translates to:
  /// **'Basque'**
  String get languageNameEus;

  /// Name of the language with ISO 639-2 code mya
  ///
  /// In en, this message translates to:
  /// **'Burmese'**
  String get languageNameMya;

  /// Name of the language with ISO 639-2 code kat
  ///
  /// In en, this message translates to:
  /// **'Georgian'**
  String get languageNameKat;

  /// Name of the language with ISO 639-2 code isl
  ///
  /// In en, this message translates to:
  /// **'Icelandic'**
  String get languageNameIsl;

  /// Name of the language with ISO 639-2 code mkd
  ///
  /// In en, this message translates to:
  /// **'Macedonian'**
  String get languageNameMkd;

  /// Name of the language with ISO 639-2 code mri
  ///
  /// In en, this message translates to:
  /// **'Maori'**
  String get languageNameMri;

  /// Name of the language with ISO 639-2 code bod
  ///
  /// In en, this message translates to:
  /// **'Tibetan'**
  String get languageNameBod;

  /// Name of the language with ISO 639-2 code zxx
  ///
  /// In en, this message translates to:
  /// **'No lyrics'**
  String get languageNameZxx;

  /// Name of the language with ISO 639-2 code mul
  ///
  /// In en, this message translates to:
  /// **'Multiple languages'**
  String get languageNameMul;

  /// No description provided for @languagesNoRootsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a music folder in Songs.'**
  String get languagesNoRootsMessage;

  /// No description provided for @languagesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No languages yet'**
  String get languagesEmptyTitle;

  /// No description provided for @languagesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Songs with a language tag (TLAN in MP3, LANGUAGE in FLAC and Ogg) show up here by language. Rescan your folders to read the tags.'**
  String get languagesEmptyMessage;

  /// No description provided for @languagesAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get languagesAlbums;

  /// No description provided for @languagesSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get languagesSongs;

  /// No description provided for @languagesNotFound.
  ///
  /// In en, this message translates to:
  /// **'Language not found'**
  String get languagesNotFound;

  /// No description provided for @languagesNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Its songs may have been removed or retagged.'**
  String get languagesNotFoundMessage;

  /// Artist line of an album merged from several album artists
  ///
  /// In en, this message translates to:
  /// **'Various artists'**
  String get albumVariousArtists;

  /// Hint of the filter box inside a page or the queue
  ///
  /// In en, this message translates to:
  /// **'Filter songs'**
  String get inPageSearchHint;

  /// Tooltip of the button that opens the filter box of a page or the queue
  ///
  /// In en, this message translates to:
  /// **'Filter in this page'**
  String get inPageSearchOpen;

  /// Tooltip of the button that empties the filter box
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get inPageSearchClear;

  /// Shown when the filter of a page or the queue matches no song
  ///
  /// In en, this message translates to:
  /// **'No songs match “{query}”'**
  String inPageSearchNoMatch(String query);

  /// Shown under the filtered playlist when more songs matched than it lists
  ///
  /// In en, this message translates to:
  /// **'Showing the first {count} songs. Type more to narrow it down.'**
  String inPageSearchTooMany(int count);

  /// Title of the recently played section on Home
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get homeRecentlyPlayedTitle;

  /// Title of the recently added section on Home
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get homeRecentlyAddedTitle;

  /// Title of the section with songs played around this date last year
  ///
  /// In en, this message translates to:
  /// **'Lost memories'**
  String get homeMemoriesTitle;

  /// Title of the recent albums section on Home
  ///
  /// In en, this message translates to:
  /// **'Recent albums'**
  String get homeRecentAlbumsTitle;

  /// Title of the recent artists section on Home
  ///
  /// In en, this message translates to:
  /// **'Recent artists'**
  String get homeRecentArtistsTitle;

  /// Shown when no song was played around this date last year
  ///
  /// In en, this message translates to:
  /// **'No music from this time last year'**
  String get homeMemoriesEmpty;

  /// Chip that shows every added song, whatever its age
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get homeAddedWindowAll;

  /// Tooltip of the button beside a Home section title
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// Tooltip of the left arrow on a Home row
  ///
  /// In en, this message translates to:
  /// **'Scroll back'**
  String get homeScrollBack;

  /// Tooltip of the right arrow on a Home row
  ///
  /// In en, this message translates to:
  /// **'Scroll forward'**
  String get homeScrollForward;

  /// Chip that shows songs added in the last N days
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String homeAddedWindowDays(int count);

  /// Shown on the full recently added list when no song was added in the chosen period
  ///
  /// In en, this message translates to:
  /// **'No songs were added in this period'**
  String get homeRecentlyAddedEmpty;

  /// Shown on the full recent albums list when no album was played
  ///
  /// In en, this message translates to:
  /// **'No albums played yet'**
  String get homeRecentAlbumsEmpty;

  /// Shown on the full recent artists list when no artist was played
  ///
  /// In en, this message translates to:
  /// **'No artists played yet'**
  String get homeRecentArtistsEmpty;

  /// Shown on a full Home list when a page could not be read
  ///
  /// In en, this message translates to:
  /// **'Could not load the list'**
  String get homeLoadFailed;

  /// Text button under the failure sentence of a full Home list that reads the list again
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get homeRetry;
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
