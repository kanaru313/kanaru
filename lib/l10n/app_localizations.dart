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

  /// Song menu row that opens the in-app folder page of the song's folder
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get libraryShowInFolder;

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

  /// Hint of the filter box on a full album list
  ///
  /// In en, this message translates to:
  /// **'Filter albums'**
  String get albumsFilterHint;

  /// Shown on a full album list when no album matches the filter text
  ///
  /// In en, this message translates to:
  /// **'No albums match “{query}”'**
  String albumsFilterNoMatch(String query);

  /// Subtitle of a full album list: whose albums, and how many (or how many are shown)
  ///
  /// In en, this message translates to:
  /// **'{owner} · {albums}'**
  String albumsOwnerSummary(String owner, String albums);

  /// Albums matching the filter out of all of them, e.g. 3 / 12 albums
  ///
  /// In en, this message translates to:
  /// **'{shown} / {albums}'**
  String albumsShownOfTotal(int shown, String albums);

  /// Shown on a full album list whose albums all vanished after a library update
  ///
  /// In en, this message translates to:
  /// **'No albums here any more'**
  String get albumsSectionEmpty;

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

  /// No description provided for @foldersFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get foldersFilterAll;

  /// No description provided for @foldersSectionFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders · {count}'**
  String foldersSectionFolders(int count);

  /// No description provided for @foldersSectionSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs · {count}'**
  String foldersSectionSongs(int count);

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

  /// No description provided for @foldersPlayAllBelow.
  ///
  /// In en, this message translates to:
  /// **'Play all below'**
  String get foldersPlayAllBelow;

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

  /// Title of the Lyrics section in Settings
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get settingsLyrics;

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

  /// Shown in the lyrics slot of Now Playing when the song has no lyrics
  ///
  /// In en, this message translates to:
  /// **'No lyrics for this song'**
  String get lyricsNone;

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

  /// Tooltip of the Now Playing header button that opens the lyrics translation menu
  ///
  /// In en, this message translates to:
  /// **'Lyrics translation'**
  String get lyricsTranslationButton;

  /// Tooltip of the translation button while a translation is being fetched
  ///
  /// In en, this message translates to:
  /// **'Lyrics translation: translating'**
  String get lyricsTranslationButtonLoading;

  /// Tooltip of the translation button after a translation failed
  ///
  /// In en, this message translates to:
  /// **'Lyrics translation: failed'**
  String get lyricsTranslationButtonFailed;

  /// Switch in the lyrics translation menu; a key hint follows it
  ///
  /// In en, this message translates to:
  /// **'Show translation'**
  String get lyricsTranslationShow;

  /// Submenu title in the lyrics translation menu; language is the language name
  ///
  /// In en, this message translates to:
  /// **'Translate to: {language}'**
  String lyricsTranslationTarget(String language);

  /// First item of the target language submenu: clears the choice made for this song; language is the default language name
  ///
  /// In en, this message translates to:
  /// **'Default ({language})'**
  String lyricsTranslationTargetDefault(String language);

  /// Heading of the display style choices in the lyrics translation menu
  ///
  /// In en, this message translates to:
  /// **'Display style'**
  String get lyricsTranslationDisplayHeader;

  /// Display style that puts the translation under each original line
  ///
  /// In en, this message translates to:
  /// **'Under each line'**
  String get lyricsTranslationDisplayUnder;

  /// Display style that shows the translation instead of the original line
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get lyricsTranslationDisplayReplace;

  /// Heading of the translation service choices in the lyrics translation menu
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get lyricsTranslationServiceHeader;

  /// Footer of the lyrics translation menu when a saved translation shows
  ///
  /// In en, this message translates to:
  /// **'Translation saved'**
  String get lyricsTranslationSaved;

  /// Footer of the lyrics translation menu when the shown translation came from the other service; service is Google or DeepL
  ///
  /// In en, this message translates to:
  /// **'Saved from {service}'**
  String lyricsTranslationSavedFrom(String service);

  /// Button in the lyrics translation menu that translates again with the selected service
  ///
  /// In en, this message translates to:
  /// **'Retranslate'**
  String get lyricsTranslationRetranslate;

  /// Button in the lyrics translation menu that translates again with the selected service; service is Google or DeepL
  ///
  /// In en, this message translates to:
  /// **'Retranslate with {service}'**
  String lyricsTranslationRetranslateWith(String service);

  /// Footer of the lyrics translation menu and tooltip of the translate button when nothing needs translating; language is the language name
  ///
  /// In en, this message translates to:
  /// **'Lyrics are already in {language}'**
  String lyricsTranslationSameLanguage(String language);

  /// Footer of the lyrics translation menu while a translation is being fetched
  ///
  /// In en, this message translates to:
  /// **'Translating…'**
  String get lyricsTranslationLoading;

  /// Button in the lyrics translation menu after a failure
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get lyricsTranslationRetry;

  /// Why a translation failed: no network
  ///
  /// In en, this message translates to:
  /// **'Could not reach the service. Check your connection.'**
  String get lyricsTranslationFailNetwork;

  /// Why a translation failed: DeepL selected without a key
  ///
  /// In en, this message translates to:
  /// **'Add your DeepL API key in Settings.'**
  String get lyricsTranslationFailNoKey;

  /// Why a translation failed: wrong DeepL key
  ///
  /// In en, this message translates to:
  /// **'DeepL rejected the API key. Check it in Settings.'**
  String get lyricsTranslationFailBadKey;

  /// Why a translation failed: DeepL quota used up
  ///
  /// In en, this message translates to:
  /// **'The monthly character quota is used up.'**
  String get lyricsTranslationFailQuota;

  /// Why a translation failed: rate limited
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Try again in a moment.'**
  String get lyricsTranslationFailRateLimited;

  /// Why a translation failed: blocked
  ///
  /// In en, this message translates to:
  /// **'The service blocked the request. Try again later or use the other service.'**
  String get lyricsTranslationFailBlocked;

  /// Why a translation failed: target language not supported
  ///
  /// In en, this message translates to:
  /// **'This service cannot translate into this language.'**
  String get lyricsTranslationFailUnsupportedLanguage;

  /// Why a translation failed: lyrics too long
  ///
  /// In en, this message translates to:
  /// **'These lyrics are too long to translate.'**
  String get lyricsTranslationFailTooLong;

  /// Why a translation failed: server error
  ///
  /// In en, this message translates to:
  /// **'The service had an error. Try again later.'**
  String get lyricsTranslationFailServer;

  /// Why a translation failed: unreadable answer
  ///
  /// In en, this message translates to:
  /// **'The service sent an answer that could not be read.'**
  String get lyricsTranslationFailInvalidResponse;

  /// Why a translation failed: empty answer
  ///
  /// In en, this message translates to:
  /// **'The service returned no translation.'**
  String get lyricsTranslationFailEmptyResult;

  /// Why a translation failed: the system key store is locked
  ///
  /// In en, this message translates to:
  /// **'The key store is locked. Unlock it to use your DeepL key.'**
  String get lyricsTranslationFailKeyStoreLocked;

  /// Why a translation failed: no system key store
  ///
  /// In en, this message translates to:
  /// **'The key store is not available, so the DeepL key cannot be read.'**
  String get lyricsTranslationFailKeyStoreUnavailable;

  /// Tooltip of the translate button while translated lyrics show: who translated them. service is Google or DeepL, language the language name
  ///
  /// In en, this message translates to:
  /// **'Translated by {service} · {language}'**
  String lyricsTranslationAttribution(String service, String language);

  /// Text of the translate button in the header while translated lyrics show. service is Google or DeepL, language the language name
  ///
  /// In en, this message translates to:
  /// **'{service} · {language}'**
  String lyricsTranslationButtonLabel(String service, String language);

  /// Button of the lyrics translation error banner that switches to the other service; service is Google or DeepL
  ///
  /// In en, this message translates to:
  /// **'Use {service}'**
  String lyricsTranslationUseService(String service);

  /// Lyrics translation error banner: DeepL is selected but no key is saved
  ///
  /// In en, this message translates to:
  /// **'Add your DeepL key in Settings › Lyrics.'**
  String get lyricsTranslationBannerNoKey;

  /// Lyrics translation error banner: DeepL did not accept the saved key
  ///
  /// In en, this message translates to:
  /// **'DeepL rejected the key. Check the key in Settings › Lyrics.'**
  String get lyricsTranslationBannerBadKey;

  /// Title of the dialog asking to send lyrics to a translation service; service is Google or DeepL
  ///
  /// In en, this message translates to:
  /// **'Lyrics will be sent to {service}'**
  String translationNoticeTitle(String service);

  /// Body of the translation notice dialog; service is Google or DeepL
  ///
  /// In en, this message translates to:
  /// **'The text of this song\'s lyrics is sent to {service} to be translated. Nothing else is sent.'**
  String translationNoticeBody(String service);

  /// Extra line of the translation notice dialog when the service is Google
  ///
  /// In en, this message translates to:
  /// **'Google is used through an unofficial web address, so it may stop working at any time.'**
  String get translationNoticeGoogleUnofficial;

  /// Button of the translation notice dialog that accepts sending the lyrics
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get translationNoticeContinue;

  /// Name of Simplified Chinese as a translation language
  ///
  /// In en, this message translates to:
  /// **'Chinese (Simplified)'**
  String get languageNameZhHans;

  /// Name of Traditional Chinese as a translation language
  ///
  /// In en, this message translates to:
  /// **'Chinese (Traditional)'**
  String get languageNameZhHant;

  /// No description provided for @settingsTranslationService.
  ///
  /// In en, this message translates to:
  /// **'Translation service'**
  String get settingsTranslationService;

  /// No description provided for @settingsTranslationServiceGoogleHint.
  ///
  /// In en, this message translates to:
  /// **'Free, unofficial service; may stop working. Lyrics text is sent to it when translation is on.'**
  String get settingsTranslationServiceGoogleHint;

  /// No description provided for @settingsTranslationServiceDeeplHint.
  ///
  /// In en, this message translates to:
  /// **'Needs your own DeepL API key. Lyrics text is sent to DeepL when translation is on.'**
  String get settingsTranslationServiceDeeplHint;

  /// No description provided for @settingsTranslationTarget.
  ///
  /// In en, this message translates to:
  /// **'Default translation language'**
  String get settingsTranslationTarget;

  /// No description provided for @settingsTranslationTargetHint.
  ///
  /// In en, this message translates to:
  /// **'Used for songs that have no language of their own.'**
  String get settingsTranslationTargetHint;

  /// First choice of the default translation language; language is the app language's name
  ///
  /// In en, this message translates to:
  /// **'Follow app language ({language})'**
  String settingsTranslationTargetFollow(String language);

  /// No description provided for @deeplKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'DeepL API key'**
  String get deeplKeyTitle;

  /// No description provided for @deeplKeyNone.
  ///
  /// In en, this message translates to:
  /// **'No key saved'**
  String get deeplKeyNone;

  /// No description provided for @deeplKeyAdd.
  ///
  /// In en, this message translates to:
  /// **'Add key'**
  String get deeplKeyAdd;

  /// No description provided for @deeplKeyEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get deeplKeyEdit;

  /// No description provided for @deeplKeyClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get deeplKeyClear;

  /// No description provided for @deeplKeyPlanFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get deeplKeyPlanFree;

  /// No description provided for @deeplKeyPlanPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get deeplKeyPlanPro;

  /// DeepL quota this month; used and limit are formatted numbers
  ///
  /// In en, this message translates to:
  /// **'Used {used} of {limit} characters'**
  String deeplKeyUsage(int used, int limit);

  /// DeepL usage of a plan without a character limit
  ///
  /// In en, this message translates to:
  /// **'Used {used} characters'**
  String deeplKeyUsageNoLimit(int used);

  /// No description provided for @deeplKeyUsageHint.
  ///
  /// In en, this message translates to:
  /// **'Usage is read from DeepL when you press refresh.'**
  String get deeplKeyUsageHint;

  /// No description provided for @deeplKeyRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh usage'**
  String get deeplKeyRefresh;

  /// No description provided for @deeplKeyClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove the DeepL key?'**
  String get deeplKeyClearTitle;

  /// No description provided for @deeplKeyClearBody.
  ///
  /// In en, this message translates to:
  /// **'The key is deleted from this computer. Lyrics cannot be translated with DeepL until you add a key again.'**
  String get deeplKeyClearBody;

  /// No description provided for @deeplKeyClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the key'**
  String get deeplKeyClearFailed;

  /// No description provided for @deeplKeyDialogTitleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add DeepL API key'**
  String get deeplKeyDialogTitleAdd;

  /// No description provided for @deeplKeyDialogTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Replace DeepL API key'**
  String get deeplKeyDialogTitleEdit;

  /// No description provided for @deeplKeyDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the key from your DeepL account. DeepL checks it before it is saved.'**
  String get deeplKeyDialogHint;

  /// No description provided for @deeplKeyFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get deeplKeyFieldLabel;

  /// No description provided for @deeplKeySave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get deeplKeySave;

  /// No description provided for @deeplKeyBadKey.
  ///
  /// In en, this message translates to:
  /// **'DeepL did not accept this key. Check it and try again.'**
  String get deeplKeyBadKey;

  /// No description provided for @deeplKeySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the key.'**
  String get deeplKeySaveFailed;

  /// No description provided for @deeplKeyReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the key.'**
  String get deeplKeyReadFailed;

  /// No description provided for @deeplKeyKeyringLocked.
  ///
  /// In en, this message translates to:
  /// **'Keyring is locked; unlock it, then retry'**
  String get deeplKeyKeyringLocked;

  /// No description provided for @deeplKeyKeyringNoDefault.
  ///
  /// In en, this message translates to:
  /// **'No default keyring found; create one (for example in Seahorse or KWallet), then retry'**
  String get deeplKeyKeyringNoDefault;

  /// No description provided for @deeplKeyKeyringTimeout.
  ///
  /// In en, this message translates to:
  /// **'The keyring is not responding'**
  String get deeplKeyKeyringTimeout;

  /// No description provided for @deeplKeyKeyringUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The keyring cannot be used right now'**
  String get deeplKeyKeyringUnavailable;

  /// No description provided for @deeplKeyFileFailed.
  ///
  /// In en, this message translates to:
  /// **'The key file could not be read or written'**
  String get deeplKeyFileFailed;

  /// Warning under the DeepL key row when no system keyring exists; path is the secrets file
  ///
  /// In en, this message translates to:
  /// **'No system keyring found; the key is stored in a file only you can read ({path}). Do not share or sync this file.'**
  String deeplKeyFallbackFile(String path);

  /// No description provided for @deeplKeyFallbackMemory.
  ///
  /// In en, this message translates to:
  /// **'No system keyring found; the key is kept until Kanaru closes.'**
  String get deeplKeyFallbackMemory;

  /// No description provided for @deeplKeyFallbackFixed.
  ///
  /// In en, this message translates to:
  /// **'The key file was readable by others; its permissions were fixed. Consider replacing the key.'**
  String get deeplKeyFallbackFixed;

  /// No description provided for @settingsTranslationCache.
  ///
  /// In en, this message translates to:
  /// **'Saved translations'**
  String get settingsTranslationCache;

  /// Saved lyrics translations: number of songs and their size
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}} · {size}'**
  String translationCacheSummary(int count, String size);

  /// No description provided for @translationCacheEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved translations'**
  String get translationCacheEmpty;

  /// No description provided for @translationCacheClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear saved translations?'**
  String get translationCacheClearTitle;

  /// No description provided for @translationCacheClearBody.
  ///
  /// In en, this message translates to:
  /// **'The translations saved on this computer are deleted. Your translation settings stay; lyrics are translated again when needed.'**
  String get translationCacheClearBody;

  /// No description provided for @translationCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No saved translations to clear} =1{Cleared 1 saved translation} other{Cleared {count} saved translations}}'**
  String translationCacheCleared(int count);

  /// No description provided for @translationCacheClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear saved translations'**
  String get translationCacheClearFailed;

  /// No description provided for @settingsUnitBytes.
  ///
  /// In en, this message translates to:
  /// **'{count} B'**
  String settingsUnitBytes(int count);

  /// No description provided for @settingsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsClear;

  /// Title of the dialog asking to look lyrics up online without asking each time
  ///
  /// In en, this message translates to:
  /// **'Find lyrics online automatically?'**
  String get onlineLyricsNoticeAutoTitle;

  /// Title of the dialog asking to search the enabled online lyrics sources
  ///
  /// In en, this message translates to:
  /// **'Search lyrics online?'**
  String get onlineLyricsNoticeManualTitle;

  /// Body of the online lyrics notice dialog; one consent covers every enabled source
  ///
  /// In en, this message translates to:
  /// **'Kanaru sends the song title, artist, album and length to the sources you have turned on. No file names, paths or device details.'**
  String get onlineLyricsNoticeSourcesBody;

  /// Hint under the automatic online lyrics notice saying where to turn it off
  ///
  /// In en, this message translates to:
  /// **'You can turn it off in Settings › Lyrics.'**
  String get onlineLyricsNoticeAutoHint;

  /// Button of the automatic online lyrics notice that accepts
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get onlineLyricsNoticeTurnOn;

  /// Button of the manual online lyrics notice that accepts and searches
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get onlineLyricsNoticeSearch;

  /// Track menu row that opens the Choose lyrics dialog
  ///
  /// In en, this message translates to:
  /// **'Find lyrics online…'**
  String get lyricsFindOnline;

  /// Title of the dialog to pick online lyrics for a song
  ///
  /// In en, this message translates to:
  /// **'Choose lyrics'**
  String get lyricsPickerTitle;

  /// Subtitle of the Choose lyrics dialog; duration is m:ss
  ///
  /// In en, this message translates to:
  /// **'Song: {title} · {artist} · {duration}'**
  String lyricsPickerSong(String title, String artist, String duration);

  /// Button next to the query field of the Choose lyrics dialog
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get lyricsPickerSearch;

  /// Hint of the query field of the Choose lyrics dialog
  ///
  /// In en, this message translates to:
  /// **'Artist and title'**
  String get lyricsPickerQueryHint;

  /// Badge of a result with time-synced lyrics
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get lyricsPickerSynced;

  /// Badge of a result with plain lyrics
  ///
  /// In en, this message translates to:
  /// **'Plain'**
  String get lyricsPickerPlain;

  /// Badge of a result the service marks as instrumental
  ///
  /// In en, this message translates to:
  /// **'Instrumental'**
  String get lyricsPickerInstrumental;

  /// Label of a result whose title, artist and length fit the song
  ///
  /// In en, this message translates to:
  /// **'Good match'**
  String get lyricsPickerGoodMatch;

  /// Label of a result the user earlier marked as not the lyrics of this song
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get lyricsPickerRejected;

  /// How many seconds a result's length differs from the song's
  ///
  /// In en, this message translates to:
  /// **'±{seconds}s'**
  String lyricsPickerDelta(int seconds);

  /// Shown in the Choose lyrics dialog before any search when the query field is blank
  ///
  /// In en, this message translates to:
  /// **'Type the artist and title, then press Search'**
  String get lyricsPickerBlankHint;

  /// Shown when the search finds nothing
  ///
  /// In en, this message translates to:
  /// **'No lyrics found. Try other words.'**
  String get lyricsPickerEmpty;

  /// Button that repeats a failed lyrics search
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get lyricsPickerRetry;

  /// Footer of the Choose lyrics dialog; hosts are the web addresses of the service
  ///
  /// In en, this message translates to:
  /// **'Results from {hosts} · the lyrics you pick are pinned to this song'**
  String lyricsPickerFooter(String hosts);

  /// Button that pins the selected lyrics to the song
  ///
  /// In en, this message translates to:
  /// **'Use these lyrics'**
  String get lyricsPickerUse;

  /// Preview pane text when nothing is selected
  ///
  /// In en, this message translates to:
  /// **'Select a result to preview its lyrics'**
  String get lyricsPickerNoPreview;

  /// Preview pane text for a result without lyrics
  ///
  /// In en, this message translates to:
  /// **'These lyrics can\'t be previewed or used'**
  String get lyricsPickerNoBody;

  /// Preview pane text for an instrumental result
  ///
  /// In en, this message translates to:
  /// **'This song is instrumental'**
  String get lyricsPickerInstrumentalPreview;

  /// Snackbar after the user picked online lyrics
  ///
  /// In en, this message translates to:
  /// **'Lyrics chosen for this song'**
  String get lyricsPinned;

  /// Snackbar when pinning the lyrics the user picked failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t pin these lyrics'**
  String get lyricsPickFailed;

  /// Shown in the Choose lyrics dialog when the user's consent for a lyrics service was withdrawn; provider is its name
  ///
  /// In en, this message translates to:
  /// **'You haven\'t allowed lyrics search on {provider}.'**
  String lyricsPickerNotConsented(String provider);

  /// Lyrics slot of Now Playing while a lookup runs; provider is the service name
  ///
  /// In en, this message translates to:
  /// **'Searching {provider}…'**
  String lyricsSearching(String provider);

  /// Button in the empty lyrics slot that turns on automatic online lookup
  ///
  /// In en, this message translates to:
  /// **'Find lyrics automatically'**
  String get lyricsFindAutomatically;

  /// Lyrics slot of Now Playing when the service has no match; provider is its name
  ///
  /// In en, this message translates to:
  /// **'No lyrics found on {provider}'**
  String lyricsNotFound(String provider);

  /// Button in the empty lyrics slot that opens the Choose lyrics dialog
  ///
  /// In en, this message translates to:
  /// **'Search manually…'**
  String get lyricsSearchManually;

  /// Banner above the empty lyrics slot after a failed lookup; provider is its name
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach {provider}'**
  String lyricsOnlineError(String provider);

  /// Banner above the empty lyrics slot when the service kept answering that it is busy; provider is its name
  ///
  /// In en, this message translates to:
  /// **'{provider} is busy. Try again in a moment.'**
  String lyricsOnlineBusy(String provider);

  /// Button on the failed lookup banner
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get lyricsRetry;

  /// Button in the lyrics slot that opens the Choose lyrics dialog
  ///
  /// In en, this message translates to:
  /// **'Choose lyrics…'**
  String get lyricsChoose;

  /// Lyrics slot of Now Playing for a song the service marks as instrumental
  ///
  /// In en, this message translates to:
  /// **'Instrumental'**
  String get lyricsInstrumental;

  /// Lyrics credit menu item that rejects the matched lyrics for the song
  ///
  /// In en, this message translates to:
  /// **'Not these lyrics'**
  String get lyricsMenuNotThese;

  /// No description provided for @settingsAutoOnlineLyrics.
  ///
  /// In en, this message translates to:
  /// **'Find lyrics online automatically'**
  String get settingsAutoOnlineLyrics;

  /// No description provided for @settingsAutoOnlineLyricsHint.
  ///
  /// In en, this message translates to:
  /// **'While Now Playing is open, for songs without lyrics on this computer. \"Find lyrics online…\" in the song menu always works.'**
  String get settingsAutoOnlineLyricsHint;

  /// No description provided for @settingsSavedLyrics.
  ///
  /// In en, this message translates to:
  /// **'Saved lyrics'**
  String get settingsSavedLyrics;

  /// Saved lyrics summary: songs that have lyrics
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song with lyrics} other{{count} songs with lyrics}}'**
  String settingsSavedLyricsSongs(int count);

  /// Saved lyrics summary: songs the service had none for
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} not found}}'**
  String settingsSavedLyricsNotFound(int count);

  /// Saved lyrics summary: songs with a chosen lyrics source
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 source choice} other{{count} source choices}}'**
  String settingsSavedLyricsChoices(int count);

  /// Saved lyrics summary: lyrics versions the user rejected
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} rejected}}'**
  String settingsSavedLyricsRejects(int count);

  /// No description provided for @settingsLyricsConsent.
  ///
  /// In en, this message translates to:
  /// **'Online lyrics search permission'**
  String get settingsLyricsConsent;

  /// No description provided for @settingsLyricsConsentNone.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get settingsLyricsConsentNone;

  /// No description provided for @settingsLyricsConsentManual.
  ///
  /// In en, this message translates to:
  /// **'Manual search allowed'**
  String get settingsLyricsConsentManual;

  /// No description provided for @settingsLyricsConsentAuto.
  ///
  /// In en, this message translates to:
  /// **'Manual and automatic search allowed'**
  String get settingsLyricsConsentAuto;

  /// No description provided for @settingsLyricsConsentWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get settingsLyricsConsentWithdraw;

  /// No description provided for @settingsLyricsConsentWithdrawTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdraw permission?'**
  String get settingsLyricsConsentWithdrawTitle;

  /// No description provided for @settingsLyricsConsentWithdrawBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing is sent to online lyrics sources any more, and automatic search turns off. Saved lyrics stay, and you will be asked again before the next search.'**
  String get settingsLyricsConsentWithdrawBody;

  /// No description provided for @settingsSavedLyricsNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved'**
  String get settingsSavedLyricsNone;

  /// No description provided for @settingsSavedLyricsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsSavedLyricsClear;

  /// No description provided for @settingsSavedLyricsClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear saved lyrics?'**
  String get settingsSavedLyricsClearTitle;

  /// No description provided for @settingsSavedLyricsClearBody.
  ///
  /// In en, this message translates to:
  /// **'Deleted: the lyrics saved on this computer, the lyrics source chosen for each song and the rejected versions. .lrc files next to songs stay.'**
  String get settingsSavedLyricsClearBody;

  /// No description provided for @settingsSavedLyricsCleared.
  ///
  /// In en, this message translates to:
  /// **'Saved lyrics cleared'**
  String get settingsSavedLyricsCleared;

  /// No description provided for @settingsSavedLyricsClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear saved lyrics'**
  String get settingsSavedLyricsClearFailed;

  /// Title of the Save lyrics dialog
  ///
  /// In en, this message translates to:
  /// **'Save lyrics'**
  String get lyricsSaveTitle;

  /// Save lyrics option: a .lrc file next to the song
  ///
  /// In en, this message translates to:
  /// **'.lrc file'**
  String get lyricsSaveOptionLrc;

  /// Save lyrics option, not available yet
  ///
  /// In en, this message translates to:
  /// **'In the music tags'**
  String get lyricsSaveOptionTags;

  /// Shown under the disabled tag option of Save lyrics
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get lyricsSaveOptionTagsSoon;

  /// Confirm button of the Save lyrics dialog
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get lyricsSaveConfirm;

  /// Title of the confirm before an existing .lrc file is replaced; files are the names of the lyrics files, title the song
  ///
  /// In en, this message translates to:
  /// **'Replace {files} of {title}?'**
  String lyricsReplaceTitle(String files, String title);

  /// Body of the replace confirm
  ///
  /// In en, this message translates to:
  /// **'The old file is moved to the trash.'**
  String get lyricsReplaceBody;

  /// Confirm button of the replace confirm
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get lyricsReplaceAction;

  /// Snackbar after the .lrc file was written
  ///
  /// In en, this message translates to:
  /// **'Lyrics saved as a .lrc file'**
  String get lyricsSaveWritten;

  /// Snackbar when the .lrc file already holds the same text
  ///
  /// In en, this message translates to:
  /// **'The .lrc file already has these lyrics'**
  String get lyricsSaveIdentical;

  /// Details under the save snackbar when tags win over the saved file
  ///
  /// In en, this message translates to:
  /// **'The song still uses the lyrics you chose because lyrics in tags are preferred'**
  String get lyricsSaveKeptTag;

  /// Details under the save snackbar when another lyrics file is read
  ///
  /// In en, this message translates to:
  /// **'The song still uses the lyrics you chose because Kanaru reads another lyrics file of the song'**
  String get lyricsSaveKeptOtherFile;

  /// Snackbar when the song is not in a library folder
  ///
  /// In en, this message translates to:
  /// **'Could not save: the song is outside the library folders'**
  String get lyricsSaveOutsideLibrary;

  /// Snackbar when writing the .lrc file failed
  ///
  /// In en, this message translates to:
  /// **'Could not save the .lrc file (read-only folder, no space or no permission)'**
  String get lyricsSaveFailed;

  /// Snackbar when the old file could not be trashed
  ///
  /// In en, this message translates to:
  /// **'Could not move the old file to the trash, so nothing was replaced'**
  String get lyricsSaveTrashFailed;

  /// Snackbar when the old file is in the trash and the new one is missing
  ///
  /// In en, this message translates to:
  /// **'The old file was moved to the trash but the new one could not be written; restore it from the trash if needed'**
  String get lyricsSaveTrashedNotWritten;

  /// Snackbar when the lyrics are instrumental, empty or gone
  ///
  /// In en, this message translates to:
  /// **'No lyrics to save'**
  String get lyricsSaveNothing;

  /// Snackbar when the trash timed out on the first old file
  ///
  /// In en, this message translates to:
  /// **'The trash did not answer in time; the old file may be in the trash and no new file was written'**
  String get lyricsSaveTrashTimedOut;

  /// Snackbar when a lyrics file appeared during a replace
  ///
  /// In en, this message translates to:
  /// **'Another lyrics file just appeared, so nothing was replaced'**
  String get lyricsSaveReplaceRaced;

  /// Joins the names of two lyrics files in the replace confirm
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String lyricsReplaceFilesJoin(String first, String second);

  /// Lyrics source button label when the user turned lyrics off for the song
  ///
  /// In en, this message translates to:
  /// **'Lyrics off'**
  String get lyricsSourceOff;

  /// Lyrics source button label while a lookup runs
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get lyricsSourceSearching;

  /// Lyrics source button label while automatic lookups wait after a failure
  ///
  /// In en, this message translates to:
  /// **'Lookups paused'**
  String get lyricsSourcePaused;

  /// Lyrics source button label when the song has no lyrics
  ///
  /// In en, this message translates to:
  /// **'No lyrics'**
  String get lyricsSourceNone;

  /// Lyrics source button label and menu subtitle: lyrics from the .lrc file next to the song
  ///
  /// In en, this message translates to:
  /// **'.lrc file'**
  String get lyricsSourceFile;

  /// Lyrics source button label: lyrics stored in the song's tags
  ///
  /// In en, this message translates to:
  /// **'Tag lyrics'**
  String get lyricsSourceTag;

  /// Kind of online lyrics with timing, in the source button and menu
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get lyricsSourceSynced;

  /// Kind of online lyrics without timing, in the source button and menu
  ///
  /// In en, this message translates to:
  /// **'Plain'**
  String get lyricsSourcePlain;

  /// Lyrics source button label for chosen online lyrics; provider is the service name, kind is Synced or Plain
  ///
  /// In en, this message translates to:
  /// **'{provider} · {kind}'**
  String lyricsSourceOnline(String provider, String kind);

  /// Lyrics source button label when the lyrics were picked automatically; label says which
  ///
  /// In en, this message translates to:
  /// **'Auto · {label}'**
  String lyricsSourceAuto(String label);

  /// Heading of the lyrics source menu
  ///
  /// In en, this message translates to:
  /// **'Lyrics for this song'**
  String get lyricsSourceMenuHeader;

  /// Heading of the lyrics source menu and tooltip of its button when lyrics are shown; source says where they come from, such as "LRCLIB · Synced" or ".lrc file"
  ///
  /// In en, this message translates to:
  /// **'Lyrics from {source}'**
  String lyricsSourceMenuFrom(String source);

  /// Lyrics source menu item that lets Kanaru pick the lyrics
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get lyricsSourceAutoItem;

  /// Subtitle of the Automatic item naming the lyrics now shown
  ///
  /// In en, this message translates to:
  /// **'In use: {label}'**
  String lyricsSourceAutoNow(String label);

  /// Subtitle of the Automatic item when no online lyrics source is enabled
  ///
  /// In en, this message translates to:
  /// **'The file or tag only'**
  String get lyricsSourceAutoHintLocalOnly;

  /// Subtitle of the Automatic item while at least one online lyrics source (built in or plugin) is enabled
  ///
  /// In en, this message translates to:
  /// **'The file or tag first, then online sources'**
  String get lyricsSourceAutoHint;

  /// Subtitle of the Automatic item when a chosen online version is stored and would be forgotten
  ///
  /// In en, this message translates to:
  /// **'{text} · drops the chosen version'**
  String lyricsSourceForgetPick(String text);

  /// Lyrics source menu item for the song's own lyrics
  ///
  /// In en, this message translates to:
  /// **'Lyrics in the file'**
  String get lyricsSourceLocalItem;

  /// Subtitle of the file item when the lyrics are in the song's tags
  ///
  /// In en, this message translates to:
  /// **'In the tag'**
  String get lyricsSourceLocalTag;

  /// Subtitle of the file item when the song has no own lyrics
  ///
  /// In en, this message translates to:
  /// **'No lyrics found in the file'**
  String get lyricsSourceLocalMissing;

  /// Lyrics source menu item for the online lyrics picked for the song
  ///
  /// In en, this message translates to:
  /// **'{provider} · chosen version'**
  String lyricsSourceOnlineItem(String provider);

  /// Subtitle of the chosen online item; kind is Synced or Plain, length is m:ss
  ///
  /// In en, this message translates to:
  /// **'{kind} · {length}'**
  String lyricsSourceOnlineSubtitle(String kind, String length);

  /// Lyrics source menu item that picks the automatic match for good
  ///
  /// In en, this message translates to:
  /// **'Keep this one'**
  String get lyricsSourceKeep;

  /// Lyrics source menu item that opens the save dialog
  ///
  /// In en, this message translates to:
  /// **'Save current lyrics…'**
  String get lyricsSourceSave;

  /// Lyrics source menu item that hides lyrics for the song
  ///
  /// In en, this message translates to:
  /// **'Turn lyrics off for this song'**
  String get lyricsSourceTurnOff;

  /// Lyrics slot text when the user turned lyrics off for the song
  ///
  /// In en, this message translates to:
  /// **'Lyrics are off for this song'**
  String get lyricsOffTitle;

  /// Button in the lyrics slot that returns the song to automatic lyrics
  ///
  /// In en, this message translates to:
  /// **'Turn back on'**
  String get lyricsOffTurnOn;

  /// Lyrics slot text while automatic lookups are paused; provider is the service name, time when they resume
  ///
  /// In en, this message translates to:
  /// **'{provider} is busy. Kanaru searches again at {time}'**
  String lyricsPausedTitle(String provider, DateTime time);

  /// Banner above the empty lyrics slot when the service answered with a server error (for example 502); provider is its name
  ///
  /// In en, this message translates to:
  /// **'{provider} is having trouble, try again later'**
  String lyricsOnlineServerError(String provider);

  /// Banner above the empty lyrics slot when the service sent an answer that could not be read; provider is its name
  ///
  /// In en, this message translates to:
  /// **'{provider} answered but Kanaru could not read it'**
  String lyricsOnlineUnreadable(String provider);

  /// Snackbar after turning on automatic lookup for a song that cannot be looked up automatically
  ///
  /// In en, this message translates to:
  /// **'This song lacks a title, artist or length, so Kanaru cannot look it up automatically. Use Find lyrics online…'**
  String get lyricsAutoNeedsTags;

  /// Title of the lyrics sources page and of its row in Settings
  ///
  /// In en, this message translates to:
  /// **'Lyrics sources'**
  String get lyricsSourcesTitle;

  /// Subtitle of the Lyrics sources row in Settings; names is the enabled sources, count how many
  ///
  /// In en, this message translates to:
  /// **'{names} · {count} on'**
  String lyricsSourcesRowSubtitle(String names, int count);

  /// No description provided for @lyricsSourcesRowNoneOn.
  ///
  /// In en, this message translates to:
  /// **'Every source is off'**
  String get lyricsSourcesRowNoneOn;

  /// No description provided for @lyricsSourcesInfo.
  ///
  /// In en, this message translates to:
  /// **'Kanaru tries the enabled sources from top to bottom when it looks up lyrics automatically. Choose lyrics searches every enabled source, and you can drag the handle to change the order.'**
  String get lyricsSourcesInfo;

  /// No description provided for @lyricsSourcesStore.
  ///
  /// In en, this message translates to:
  /// **'Plugin store'**
  String get lyricsSourcesStore;

  /// No description provided for @lyricsSourcesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'No plugins installed yet. You can add some from the Plugin store.'**
  String get lyricsSourcesEmptyHint;

  /// No description provided for @lyricsSourceBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built in'**
  String get lyricsSourceBuiltIn;

  /// Subline of the built-in LRCLIB source; hosts is the address it connects to
  ///
  /// In en, this message translates to:
  /// **'Built in · {hosts}'**
  String lyricsSourceBuiltInHosts(String hosts);

  /// No description provided for @lyricsSourceDragHandle.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder (keyboard: Alt + Up or Down arrow)'**
  String get lyricsSourceDragHandle;

  /// No description provided for @lyricsSourceUnknownAuthor.
  ///
  /// In en, this message translates to:
  /// **'Unknown author'**
  String get lyricsSourceUnknownAuthor;

  /// Author of a plugin as the plugin states it; Kanaru does not verify it
  ///
  /// In en, this message translates to:
  /// **'{author} (self-declared)'**
  String lyricsSourceAuthor(String author);

  /// Where a plugin was installed from: a zip file
  ///
  /// In en, this message translates to:
  /// **'File: {name}'**
  String lyricsSourceFromFile(String name);

  /// Where a plugin was installed from: a plugin repository
  ///
  /// In en, this message translates to:
  /// **'Repo: {name}'**
  String lyricsSourceFromRepo(String name);

  /// No description provided for @lyricsSourcesMenuLogFolder.
  ///
  /// In en, this message translates to:
  /// **'Open log folder'**
  String get lyricsSourcesMenuLogFolder;

  /// No description provided for @lyricsSourcesMenuGuide.
  ///
  /// In en, this message translates to:
  /// **'Plugin writing guide'**
  String get lyricsSourcesMenuGuide;

  /// No description provided for @pluginUninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall plugin'**
  String get pluginUninstall;

  /// No description provided for @pluginGone.
  ///
  /// In en, this message translates to:
  /// **'This plugin is no longer installed.'**
  String get pluginGone;

  /// Banner on the installed plugin page when its repository lists a newer version
  ///
  /// In en, this message translates to:
  /// **'New version v{version}'**
  String pluginUpdateAvailable(int version);

  /// App bar title of the page of one plugin, installed or from a catalog; the plugin name is in the header below
  ///
  /// In en, this message translates to:
  /// **'Plugin details'**
  String get pluginDetailsTitle;

  /// Action of the error snackbar when an update did not match the repository list; it only refreshes the list
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get pluginUpdateRefreshList;

  /// Subtitle of an update row in the plugin store: installed version, then the version in the list
  ///
  /// In en, this message translates to:
  /// **'v{installed} → v{available}'**
  String lyricsStoreUpdateVersions(int installed, int available);

  /// Button of the update banner on the installed plugin page
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get pluginUpdateAction;

  /// Snackbar title when updating an installed plugin failed
  ///
  /// In en, this message translates to:
  /// **'Could not update {name}'**
  String pluginUpdateFailed(String name);

  /// No description provided for @pluginInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get pluginInfoTitle;

  /// No description provided for @pluginInfoSource.
  ///
  /// In en, this message translates to:
  /// **'Installed from'**
  String get pluginInfoSource;

  /// No description provided for @pluginInfoHosts.
  ///
  /// In en, this message translates to:
  /// **'Can only connect to'**
  String get pluginInfoHosts;

  /// No description provided for @pluginInfoInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get pluginInfoInstalled;

  /// When a plugin was installed and last updated; both are dates
  ///
  /// In en, this message translates to:
  /// **'{installed} · updated {updated}'**
  String pluginInfoInstalledUpdated(String installed, String updated);

  /// No description provided for @pluginInfoDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get pluginInfoDescription;

  /// No description provided for @pluginConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin settings'**
  String get pluginConfigTitle;

  /// No description provided for @pluginSecretNote.
  ///
  /// In en, this message translates to:
  /// **'Secret: kept in the system keyring, never in settings or logs.'**
  String get pluginSecretNote;

  /// No description provided for @pluginSecretSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved in the system keyring'**
  String get pluginSecretSaved;

  /// No description provided for @pluginSecretFallbackNote.
  ///
  /// In en, this message translates to:
  /// **'No system keyring found; secret values are kept in a file only you can read, or only until Kanaru closes. Do not share or sync that file.'**
  String get pluginSecretFallbackNote;

  /// No description provided for @pluginSecretShow.
  ///
  /// In en, this message translates to:
  /// **'Show value'**
  String get pluginSecretShow;

  /// No description provided for @pluginSecretHide.
  ///
  /// In en, this message translates to:
  /// **'Hide value'**
  String get pluginSecretHide;

  /// No description provided for @pluginSecretClear.
  ///
  /// In en, this message translates to:
  /// **'Remove saved value'**
  String get pluginSecretClear;

  /// No description provided for @pluginConfigNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get pluginConfigNumberInvalid;

  /// No description provided for @pluginConfigInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'That value is not allowed for this setting.'**
  String get pluginConfigInvalidValue;

  /// No description provided for @pluginConfigTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The plugin\'s settings are too large to save.'**
  String get pluginConfigTooLarge;

  /// No description provided for @pluginConfigUnknownKey.
  ///
  /// In en, this message translates to:
  /// **'This setting no longer exists. The plugin may have been removed or changed.'**
  String get pluginConfigUnknownKey;

  /// No description provided for @pluginConfigSecretStoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the system keyring. Unlock the keyring or restart Kanaru, then try again.'**
  String get pluginConfigSecretStoreFailed;

  /// No description provided for @pluginDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get pluginDataTitle;

  /// No description provided for @pluginStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin\'s own storage'**
  String get pluginStorageTitle;

  /// Space a plugin's own storage uses out of its limit; both are sizes
  ///
  /// In en, this message translates to:
  /// **'{used} / {limit}'**
  String pluginStorageUsage(String used, String limit);

  /// No description provided for @pluginSavedLyricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lyrics saved from this source'**
  String get pluginSavedLyricsTitle;

  /// No description provided for @pluginSavedLyricsNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get pluginSavedLyricsNone;

  /// Lyrics saved from one source: how many songs and their size
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}} · {size}'**
  String pluginSavedLyricsSummary(int count, String size);

  /// No description provided for @pluginDataClear.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get pluginDataClear;

  /// No description provided for @pluginStorageClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the plugin\'s storage?'**
  String get pluginStorageClearTitle;

  /// No description provided for @pluginStorageClearBody.
  ///
  /// In en, this message translates to:
  /// **'The plugin may have to sign in or set itself up again.'**
  String get pluginStorageClearBody;

  /// No description provided for @pluginStorageCleared.
  ///
  /// In en, this message translates to:
  /// **'Storage deleted'**
  String get pluginStorageCleared;

  /// No description provided for @pluginSavedLyricsClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete saved lyrics from this source?'**
  String get pluginSavedLyricsClearTitle;

  /// No description provided for @pluginSavedLyricsClearBody.
  ///
  /// In en, this message translates to:
  /// **'The lyrics saved from this source are deleted. Lyrics you pinned and .lrc files stay.'**
  String get pluginSavedLyricsClearBody;

  /// No description provided for @pluginSavedLyricsCleared.
  ///
  /// In en, this message translates to:
  /// **'Saved lyrics deleted'**
  String get pluginSavedLyricsCleared;

  /// No description provided for @pluginDataFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the data'**
  String get pluginDataFailed;

  /// Title of the dialog that asks to uninstall a plugin
  ///
  /// In en, this message translates to:
  /// **'Uninstall {name}?'**
  String pluginUninstallTitle(String name);

  /// No description provided for @pluginUninstallRemoves.
  ///
  /// In en, this message translates to:
  /// **'Will be deleted'**
  String get pluginUninstallRemoves;

  /// No description provided for @pluginUninstallKeeps.
  ///
  /// In en, this message translates to:
  /// **'Kept'**
  String get pluginUninstallKeeps;

  /// No description provided for @pluginUninstallCode.
  ///
  /// In en, this message translates to:
  /// **'The plugin\'s code'**
  String get pluginUninstallCode;

  /// No description provided for @pluginUninstallSettings.
  ///
  /// In en, this message translates to:
  /// **'The plugin\'s settings'**
  String get pluginUninstallSettings;

  /// No description provided for @pluginUninstallSettingsSecret.
  ///
  /// In en, this message translates to:
  /// **'The plugin\'s settings, including secret values in the keyring'**
  String get pluginUninstallSettingsSecret;

  /// Item of the uninstall dialog; size is how much the plugin's own storage holds
  ///
  /// In en, this message translates to:
  /// **'Its own storage ({size})'**
  String pluginUninstallStorage(String size);

  /// Item of the uninstall dialog: lyrics saved from the plugin stay
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 saved song} other{{count} saved songs}} and lyrics pinned from this source'**
  String pluginUninstallKeepLyrics(int count);

  /// No description provided for @pluginUninstallKeepPinned.
  ///
  /// In en, this message translates to:
  /// **'Lyrics pinned from this source, if any'**
  String get pluginUninstallKeepPinned;

  /// No description provided for @pluginUninstallKeepLrc.
  ///
  /// In en, this message translates to:
  /// **'The .lrc files already written next to songs'**
  String get pluginUninstallKeepLrc;

  /// No description provided for @pluginUninstallConfirm.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get pluginUninstallConfirm;

  /// Snackbar after a plugin was uninstalled
  ///
  /// In en, this message translates to:
  /// **'Uninstalled {name}'**
  String pluginUninstalled(String name);

  /// Snackbar when uninstalling a plugin failed
  ///
  /// In en, this message translates to:
  /// **'Could not uninstall {name}'**
  String pluginUninstallFailed(String name);

  /// No description provided for @pluginProblemTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The package, or an entry in it, is too large'**
  String get pluginProblemTooLarge;

  /// No description provided for @pluginProblemNotZip.
  ///
  /// In en, this message translates to:
  /// **'The file is not a readable zip package'**
  String get pluginProblemNotZip;

  /// Why a plugin package was refused; detail comes from the package
  ///
  /// In en, this message translates to:
  /// **'The package has an unsafe entry name ({detail})'**
  String pluginProblemUnsafeEntry(String detail);

  /// No description provided for @pluginProblemTooManyEntries.
  ///
  /// In en, this message translates to:
  /// **'The package has too many files'**
  String get pluginProblemTooManyEntries;

  /// No description provided for @pluginProblemMissingManifest.
  ///
  /// In en, this message translates to:
  /// **'plugin.json is missing at the top of the package'**
  String get pluginProblemMissingManifest;

  /// Why a plugin package was refused; detail comes from the package
  ///
  /// In en, this message translates to:
  /// **'plugin.json is invalid at \"{detail}\"'**
  String pluginProblemInvalidManifest(String detail);

  /// No description provided for @pluginProblemInvalidManifestPlain.
  ///
  /// In en, this message translates to:
  /// **'plugin.json is invalid'**
  String get pluginProblemInvalidManifestPlain;

  /// No description provided for @pluginProblemNeedsNewerApp.
  ///
  /// In en, this message translates to:
  /// **'Needs a newer Kanaru: the plugin uses a newer plugin API than this version supports'**
  String get pluginProblemNeedsNewerApp;

  /// No description provided for @pluginProblemWrongType.
  ///
  /// In en, this message translates to:
  /// **'plugin.json: type must be lyrics'**
  String get pluginProblemWrongType;

  /// Why a plugin package was refused; detail comes from the package
  ///
  /// In en, this message translates to:
  /// **'hosts: \"{detail}\" is not a public domain name'**
  String pluginProblemBadHost(String detail);

  /// Why a plugin package was refused; detail comes from the package
  ///
  /// In en, this message translates to:
  /// **'src/{detail} is missing from the package'**
  String pluginProblemMissingScript(String detail);

  /// Why a plugin package was refused; detail comes from the package
  ///
  /// In en, this message translates to:
  /// **'The script {detail} has an error'**
  String pluginProblemScriptError(String detail);

  /// Why a plugin package was refused; detail comes from the package
  ///
  /// In en, this message translates to:
  /// **'The script {detail} has an error on line {line}'**
  String pluginProblemScriptErrorLine(String detail, int line);

  /// No description provided for @pluginProblemCheckUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Kanaru cannot check the scripts right now (the plugin runtime library did not load), so it cannot tell whether the package is valid'**
  String get pluginProblemCheckUnavailable;

  /// No description provided for @pluginRefusedNotFromRepo.
  ///
  /// In en, this message translates to:
  /// **'This plugin was installed from a file, so it has no updates. Uninstall it and install the new file.'**
  String get pluginRefusedNotFromRepo;

  /// No description provided for @pluginRefusedOlderVersion.
  ///
  /// In en, this message translates to:
  /// **'This package is older than the installed version, so it was not used.'**
  String get pluginRefusedOlderVersion;

  /// No description provided for @pluginInstallSecretsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The secrets of the earlier install could not be removed from the keyring, so the plugin was not installed again. Unlock the keyring or restart Kanaru, then try again.'**
  String get pluginInstallSecretsUnavailable;

  /// No description provided for @pluginInstallGone.
  ///
  /// In en, this message translates to:
  /// **'This plugin is no longer installed, so it cannot be updated.'**
  String get pluginInstallGone;

  /// No description provided for @pluginConfigSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the setting'**
  String get pluginConfigSaveFailed;

  /// No description provided for @pluginConfigLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the plugin\'s settings'**
  String get pluginConfigLoadFailed;

  /// No description provided for @pluginSourcesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the list of plugins'**
  String get pluginSourcesLoadFailed;

  /// No description provided for @pluginRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get pluginRetry;

  /// Name of a lyrics source whose plugin was uninstalled but whose saved lyrics are still shown
  ///
  /// In en, this message translates to:
  /// **'{name} (removed)'**
  String lyricsSourceNameRemoved(String name);

  /// Name of a lyrics source plus its author, used where two sources share a name
  ///
  /// In en, this message translates to:
  /// **'{name} · {author}'**
  String lyricsSourceNameWithAuthor(String name, String author);

  /// Label of the Choose lyrics source filter chip while it shows every source; count is how many sources returned results
  ///
  /// In en, this message translates to:
  /// **'All sources ({count})'**
  String lyricsPickerAllSources(int count);

  /// Chip label while fewer than two sources have results, and first item of the source filter menu that shows every source
  ///
  /// In en, this message translates to:
  /// **'All sources'**
  String get lyricsPickerSourceMenuAll;

  /// Screen reader label of the Choose lyrics source filter button; source is its current label
  ///
  /// In en, this message translates to:
  /// **'Source filter: {source}'**
  String lyricsPickerSourceFilterLabel(String source);

  /// Action beside a lyrics plugin failure that shows that plugin's log file in the file manager
  ///
  /// In en, this message translates to:
  /// **'View log'**
  String get lyricsViewLog;

  /// Title of the lyrics plugin store page
  ///
  /// In en, this message translates to:
  /// **'Plugin store'**
  String get lyricsStoreTitle;

  /// Hint of the store search field
  ///
  /// In en, this message translates to:
  /// **'Search by name, author, repo, host'**
  String get lyricsStoreSearchHint;

  /// Source chip that shows every plugin
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get lyricsStoreChipAll;

  /// Source chip and row subtitle of a plugin installed from a zip file
  ///
  /// In en, this message translates to:
  /// **'From file'**
  String get lyricsStoreFromFile;

  /// Store section of plugins with a newer version
  ///
  /// In en, this message translates to:
  /// **'Updates ({count})'**
  String lyricsStoreSectionUpdates(int count);

  /// Store section of installed plugins
  ///
  /// In en, this message translates to:
  /// **'Installed ({count})'**
  String lyricsStoreSectionInstalled(int count);

  /// Store section of catalog plugins that are not installed
  ///
  /// In en, this message translates to:
  /// **'Not installed ({count})'**
  String lyricsStoreSectionAvailable(int count);

  /// Button that updates every plugin with an update
  ///
  /// In en, this message translates to:
  /// **'Update all'**
  String get lyricsStoreUpdateAll;

  /// Shown when the search or filter matches no plugin
  ///
  /// In en, this message translates to:
  /// **'No matching plugins.'**
  String get lyricsStoreNoMatch;

  /// Footer of the store list: plugins hidden because they need a newer app
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 plugin needs a newer Kanaru} other{{count} plugins need a newer Kanaru}}'**
  String lyricsStoreNeedsNewerFooter(int count);

  /// Banner when one repository failed to load
  ///
  /// In en, this message translates to:
  /// **'Could not load {name}: {reason}'**
  String lyricsStoreRepoFailedOne(String name, String reason);

  /// Banner when several repositories failed to load
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 repository could not be loaded} other{{count} repositories could not be loaded}}'**
  String lyricsStoreRepoFailedMany(int count);

  /// Retry button of the repository error banner
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get lyricsStoreRetry;

  /// Reason a repository could not be loaded
  ///
  /// In en, this message translates to:
  /// **'network error'**
  String get lyricsStoreLoadNetwork;

  /// Reason a repository could not be loaded
  ///
  /// In en, this message translates to:
  /// **'file not found'**
  String get lyricsStoreLoadNotFound;

  /// Reason a repository could not be loaded
  ///
  /// In en, this message translates to:
  /// **'file too large'**
  String get lyricsStoreLoadTooLarge;

  /// Reason a repository could not be loaded
  ///
  /// In en, this message translates to:
  /// **'not a valid plugin list'**
  String get lyricsStoreLoadInvalid;

  /// Reason a repository could not be loaded
  ///
  /// In en, this message translates to:
  /// **'address blocked'**
  String get lyricsStoreLoadBlocked;

  /// Tooltip of the install button of a store row
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get lyricsStoreInstallTooltip;

  /// Tooltip of the update button of a store row
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get lyricsStoreUpdateTooltip;

  /// Tooltip of the uninstall button of a store row
  ///
  /// In en, this message translates to:
  /// **'Uninstall plugin'**
  String get lyricsStoreUninstallTooltip;

  /// Semantics label of the spinner shown while a plugin is installed or updated
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get lyricsStoreWorking;

  /// Store menu item
  ///
  /// In en, this message translates to:
  /// **'Install from file…'**
  String get lyricsStoreMenuInstallFile;

  /// Store menu item that opens the repository list
  ///
  /// In en, this message translates to:
  /// **'Repositories ({count})'**
  String lyricsStoreMenuRepositories(int count);

  /// Store menu item that reloads every repository
  ///
  /// In en, this message translates to:
  /// **'Refresh all'**
  String get lyricsStoreMenuRefreshAll;

  /// Empty store title
  ///
  /// In en, this message translates to:
  /// **'No plugins yet'**
  String get lyricsStoreEmptyTitle;

  /// Button and dialog title for adding a plugin repository
  ///
  /// In en, this message translates to:
  /// **'Add repository'**
  String get lyricsStoreAddRepository;

  /// Shown when the library database is unavailable
  ///
  /// In en, this message translates to:
  /// **'The plugin store is not available right now.'**
  String get lyricsStoreUnavailable;

  /// Shown when the store data failed to load
  ///
  /// In en, this message translates to:
  /// **'Could not read the plugin store'**
  String get lyricsStoreLoadFailed;

  /// Snackbar after installing a plugin
  ///
  /// In en, this message translates to:
  /// **'Installed {name}'**
  String lyricsStoreInstalled(String name);

  /// Snackbar action that removes the plugin just installed
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get lyricsStoreUndo;

  /// Snackbar when undoing an install failed
  ///
  /// In en, this message translates to:
  /// **'Could not undo'**
  String get lyricsStoreUndoFailed;

  /// Snackbar after updating a plugin
  ///
  /// In en, this message translates to:
  /// **'Updated {name} to v{version}'**
  String lyricsStoreUpdated(String name, int version);

  /// Snackbar after update all
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Updated 1 plugin} other{Updated {count} plugins}}'**
  String lyricsStoreUpdatedAll(int count);

  /// Snackbar after update all when some updates failed
  ///
  /// In en, this message translates to:
  /// **'Updated {done}, {failed} failed'**
  String lyricsStoreUpdatedAllPartial(int done, int failed);

  /// Snackbar after uninstalling a plugin
  ///
  /// In en, this message translates to:
  /// **'Uninstalled {name}'**
  String lyricsStoreUninstalled(String name);

  /// Snackbar when uninstalling failed
  ///
  /// In en, this message translates to:
  /// **'Could not uninstall {name}'**
  String lyricsStoreUninstallFailed(String name);

  /// Install problem dialog title
  ///
  /// In en, this message translates to:
  /// **'Could not install'**
  String get lyricsStoreInstallFailedTitle;

  /// Install problem dialog line for a file
  ///
  /// In en, this message translates to:
  /// **'The file {name} is not a valid plugin.'**
  String lyricsStoreInstallFailedFile(String name);

  /// Install problem dialog line for a repository plugin
  ///
  /// In en, this message translates to:
  /// **'{name} · Repo: {repo}'**
  String lyricsStoreInstallFailedRepo(String name, String repo);

  /// Install problem dialog box title
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get lyricsStoreReasons;

  /// Catalog mismatch dialog title
  ///
  /// In en, this message translates to:
  /// **'Package does not match the list'**
  String get lyricsStoreMismatchTitle;

  /// Catalog mismatch dialog box title
  ///
  /// In en, this message translates to:
  /// **'Differences'**
  String get lyricsStoreMismatchDiffs;

  /// Catalog mismatch line
  ///
  /// In en, this message translates to:
  /// **'The list says version {catalog}, the downloaded package is version {package}'**
  String lyricsStoreMismatchVersion(int catalog, int package);

  /// Catalog mismatch line
  ///
  /// In en, this message translates to:
  /// **'The list says host {catalog}, the package declares {package}'**
  String lyricsStoreMismatchHosts(String catalog, String package);

  /// Catalog mismatch line without details
  ///
  /// In en, this message translates to:
  /// **'The package\'s version or hosts differ from the list'**
  String get lyricsStoreMismatchGeneric;

  /// Catalog mismatch hint
  ///
  /// In en, this message translates to:
  /// **'Usually the repository was just updated and a cache has not caught up. Refresh the list and try again in a few minutes. If it still differs, tell the repository owner.'**
  String get lyricsStoreMismatchHint;

  /// Catalog mismatch dialog button
  ///
  /// In en, this message translates to:
  /// **'Refresh and try again'**
  String get lyricsStoreMismatchRetry;

  /// Dialog title when a plugin needs a newer app
  ///
  /// In en, this message translates to:
  /// **'Needs a newer Kanaru'**
  String get lyricsStoreNeedsNewerTitle;

  /// Dialog body when a plugin needs a newer app
  ///
  /// In en, this message translates to:
  /// **'{name} uses a newer plugin API than this Kanaru supports. Update Kanaru and install it again.'**
  String lyricsStoreNeedsNewerBody(String name);

  /// Install failure
  ///
  /// In en, this message translates to:
  /// **'This repository is no longer in the list'**
  String get lyricsStoreFailUnknownRepo;

  /// Install failure
  ///
  /// In en, this message translates to:
  /// **'The repository no longer lists this plugin. Refresh the list.'**
  String get lyricsStoreFailUnknownEntry;

  /// Install failure
  ///
  /// In en, this message translates to:
  /// **'There is no newer version'**
  String get lyricsStoreFailNoNewerVersion;

  /// Install failure
  ///
  /// In en, this message translates to:
  /// **'Could not download the plugin package: {reason}'**
  String lyricsStoreFailDownload(String reason);

  /// Install failure
  ///
  /// In en, this message translates to:
  /// **'The plugin package is not valid'**
  String get lyricsStoreFailRejected;

  /// Install failure
  ///
  /// In en, this message translates to:
  /// **'The package does not match the list'**
  String get lyricsStoreFailMismatch;

  /// Install failure
  ///
  /// In en, this message translates to:
  /// **'Could not save the plugin (disk full or missing permission?)'**
  String get lyricsStoreFailStorage;

  /// Snackbar when a plugin action threw an unexpected error
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get lyricsStoreFailUnexpected;

  /// Snackbar when uninstalling or undoing found the plugin already removed
  ///
  /// In en, this message translates to:
  /// **'{name} was already removed'**
  String lyricsStoreAlreadyGone(String name);

  /// Download failure reason
  ///
  /// In en, this message translates to:
  /// **'package too large'**
  String get lyricsStoreFailPackageTooLarge;

  /// Author as the plugin states it
  ///
  /// In en, this message translates to:
  /// **'{author} (self-declared)'**
  String lyricsStoreItemAuthor(String author);

  /// Shown when a plugin names no author
  ///
  /// In en, this message translates to:
  /// **'Unknown author'**
  String get lyricsStoreItemUnknownAuthor;

  /// Catalog item section title
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get lyricsStoreItemInfo;

  /// Catalog item field
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get lyricsStoreItemDescription;

  /// Catalog item field
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get lyricsStoreItemRepo;

  /// Catalog item field: hosts the plugin may contact
  ///
  /// In en, this message translates to:
  /// **'Can only connect to'**
  String get lyricsStoreItemHosts;

  /// Catalog item install button
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get lyricsStoreItemInstall;

  /// Catalog item page when the entry is unknown
  ///
  /// In en, this message translates to:
  /// **'This plugin is not in the repository.'**
  String get lyricsStoreItemNotFound;

  /// Title of the repository list page
  ///
  /// In en, this message translates to:
  /// **'Repositories'**
  String get lyricsStoreReposTitle;

  /// Repository list when empty
  ///
  /// In en, this message translates to:
  /// **'No repositories yet.'**
  String get lyricsStoreReposEmpty;

  /// Tooltip of the error mark of a repository
  ///
  /// In en, this message translates to:
  /// **'The last load failed: {reason}'**
  String lyricsStoreRepoErrorTooltip(String reason);

  /// Tooltip of the remove button of a repository
  ///
  /// In en, this message translates to:
  /// **'Remove repository'**
  String get lyricsStoreRepoRemoveTooltip;

  /// Remove repository dialog title
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String lyricsStoreRemoveRepoTitle(String name);

  /// Remove repository dialog body
  ///
  /// In en, this message translates to:
  /// **'Plugins installed from this repository stay, but will no longer get updates.'**
  String get lyricsStoreRemoveRepoBody;

  /// Remove repository dialog confirm button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get lyricsStoreRemoveRepoConfirm;

  /// Snackbar after removing a repository
  ///
  /// In en, this message translates to:
  /// **'Removed {name}'**
  String lyricsStoreRepoRemoved(String name);

  /// Snackbar when removing a repository failed
  ///
  /// In en, this message translates to:
  /// **'Could not remove {name}'**
  String lyricsStoreRepoRemoveFailed(String name);

  /// Label of the add repository field
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get lyricsStoreAddUrlLabel;

  /// Add repository dialog confirm button
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get lyricsStoreAddConfirm;

  /// Add repository confirm button while loading
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get lyricsStoreAddLoading;

  /// Snackbar after adding a repository
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added {name} · 1 plugin} other{Added {name} · {count} plugins}}'**
  String lyricsStoreAddedRepo(String name, int count);

  /// Add repository error
  ///
  /// In en, this message translates to:
  /// **'A public address needs https'**
  String get lyricsStoreAddErrPublicNeedsHttps;

  /// Add repository error
  ///
  /// In en, this message translates to:
  /// **'Invalid URL'**
  String get lyricsStoreAddErrInvalidUrl;

  /// Add repository error
  ///
  /// In en, this message translates to:
  /// **'This repository is already added'**
  String get lyricsStoreAddErrDuplicate;

  /// Add repository error
  ///
  /// In en, this message translates to:
  /// **'Could not load the list: network error'**
  String get lyricsStoreAddErrNetwork;

  /// Add repository error
  ///
  /// In en, this message translates to:
  /// **'No plugin list was found at this address'**
  String get lyricsStoreAddErrNotFound;

  /// Add repository error
  ///
  /// In en, this message translates to:
  /// **'The file is not a valid plugin list'**
  String get lyricsStoreAddErrBadFormat;

  /// Add repository error
  ///
  /// In en, this message translates to:
  /// **'This address is blocked'**
  String get lyricsStoreAddErrBlocked;

  /// Add repository error with the rule that refused it
  ///
  /// In en, this message translates to:
  /// **'This address is blocked: {reason}'**
  String lyricsStoreAddErrBlockedReason(String reason);

  /// Add repository error
  ///
  /// In en, this message translates to:
  /// **'Could not save the repository'**
  String get lyricsStoreAddErrStorage;

  /// Address rule
  ///
  /// In en, this message translates to:
  /// **'the address must not contain a user name or password'**
  String get lyricsStoreAddressUserInfo;

  /// Address rule
  ///
  /// In en, this message translates to:
  /// **'a public repository must not point to a local address'**
  String get lyricsStoreAddressLocalFromPublic;

  /// Address rule
  ///
  /// In en, this message translates to:
  /// **'this address may not be reached'**
  String get lyricsStoreAddressRefused;

  /// Address rule
  ///
  /// In en, this message translates to:
  /// **'the name points to both local and public addresses'**
  String get lyricsStoreAddressMixed;

  /// Address rule
  ///
  /// In en, this message translates to:
  /// **'a local-looking name points to a public address'**
  String get lyricsStoreAddressLocalNamePublic;

  /// Mark on the catalog item page of a plugin that is installed
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get lyricsStoreItemInstalled;

  /// Button on the catalog item page of an installed plugin that opens its installed page
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get lyricsStoreItemOpenInstalled;
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
