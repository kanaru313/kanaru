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

  /// No description provided for @genresSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get genresSongs;

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

  /// No description provided for @nowPlayingComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get nowPlayingComingSoon;

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
  /// **'Off: pages and panels switch without motion.'**
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
  /// **'Songs with the same album title are one album; pick what else must match. Applies at the next rescan.'**
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
  /// **'Covers disappear until the next rescan makes them again.'**
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
  /// **'When the queue ends, Next goes back to the first song, and Previous on the first song goes to the last, whatever the repeat mode.'**
  String get settingsInfiniteQueueHint;

  /// No description provided for @settingsListenAfterTime.
  ///
  /// In en, this message translates to:
  /// **'A listen counts after'**
  String get settingsListenAfterTime;

  /// No description provided for @settingsListenAfterTimeHint.
  ///
  /// In en, this message translates to:
  /// **'This long, or the share below of the song, whichever comes first.'**
  String get settingsListenAfterTimeHint;

  /// No description provided for @settingsListenAfterShare.
  ///
  /// In en, this message translates to:
  /// **'A listen counts after (share of the song)'**
  String get settingsListenAfterShare;

  /// No description provided for @settingsListenAfterShareHint.
  ///
  /// In en, this message translates to:
  /// **'This share of the song, or the time above, whichever comes first.'**
  String get settingsListenAfterShareHint;

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
  /// **'Show each song\'s number on an album page.'**
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
