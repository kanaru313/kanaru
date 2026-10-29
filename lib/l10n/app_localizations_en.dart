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
  String get navHistory => 'History';

  @override
  String get navMostPlayed => 'Most played';

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
  String get sidebarShrink => 'Collapse sidebar';

  @override
  String get sidebarGrow => 'Expand sidebar';

  @override
  String get playlistDefaultName => 'New playlist';

  @override
  String get playlistCreateTitle => 'New playlist';

  @override
  String get playlistCreateConfirm => 'Create';

  @override
  String get playlistRename => 'Rename';

  @override
  String get playlistRenameTitle => 'Rename playlist';

  @override
  String get playlistNameLabel => 'Name';

  @override
  String get playlistDelete => 'Delete playlist';

  @override
  String playlistDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String playlistDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'It has $count songs.',
      one: 'It has 1 song.',
      zero: 'It has no songs.',
    );
    return '$_temp0 The songs stay in your library.';
  }

  @override
  String get playlistDeleteConfirm => 'Delete';

  @override
  String get playlistActions => 'Playlist actions';

  @override
  String playlistTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
      zero: 'No songs',
    );
    return '$_temp0';
  }

  @override
  String get playlistEmptyTitle => 'This playlist is empty';

  @override
  String get playlistEmptyMessage =>
      'Add songs from the menu of any song, album or artist.';

  @override
  String get playlistsEmptyMessage =>
      'Create a playlist to keep songs in your own order.';

  @override
  String get playlistNotFound => 'Playlist not found';

  @override
  String get playlistNotFoundMessage => 'It may have been deleted.';

  @override
  String get playlistNotInLibrary => 'Not in library';

  @override
  String get playlistRemoveEntry => 'Remove from playlist';

  @override
  String get playlistReorder => 'Drag to reorder';

  @override
  String get playlistAddTo => 'Add to playlist…';

  @override
  String get playlistPickerTitle => 'Add to playlist';

  @override
  String get playlistPickerNew => 'New playlist…';

  @override
  String playlistAdded(String name, String playlist) {
    return 'Added to $playlist: $name';
  }

  @override
  String playlistAddedSkipped(int added, int skipped, String playlist) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Added $added songs to $playlist',
      one: 'Added 1 song to $playlist',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped were already there',
      one: '1 was already there',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String playlistAlreadyIn(String name, String playlist) {
    return 'Already in $playlist: $name';
  }

  @override
  String get playlistSaveFailed =>
      'Couldn\'t save the playlist. See the log for details.';

  @override
  String get playlistTrackNotInLibrary =>
      'This song isn\'t in your library, so it can\'t go in a playlist.';

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
  String get libraryShuffle => 'Shuffle';

  @override
  String get libraryShowArtist => 'Show artist';

  @override
  String get libraryShowAlbum => 'Show album';

  @override
  String get libraryShowInFolder => 'Show in folder';

  @override
  String get libraryShowInFileManager => 'Show in file manager';

  @override
  String get libraryFileManagerFailed => 'Couldn\'t open the file manager';

  @override
  String get libraryTrackGone => 'This song is no longer in the library';

  @override
  String get libraryNoAlbumToShow => 'This song has no album';

  @override
  String get libraryNoArtistToShow => 'This song has no artist';

  @override
  String get libraryChooseArtist => 'Choose an artist';

  @override
  String get libraryKeysUpdatingTitle => 'Updating library…';

  @override
  String get libraryKeysUpdatingMessage =>
      'Sorting your music. Playback keeps working.';

  @override
  String libraryKeysUpdatingProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString / $totalString';
  }

  @override
  String libraryCoverProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Making covers… $doneString / $totalString';
  }

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
  String libraryScanUndecodableNames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files or folders skipped: names are not valid UTF-8',
      one: '1 file or folder skipped: its name is not valid UTF-8',
    );
    return '$_temp0';
  }

  @override
  String libraryScanRootMissing(String path) {
    return '$path was not found';
  }

  @override
  String libraryMissingRoots(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count music folders not found',
      one: 'Music folder not found: $path',
    );
    return '$_temp0';
  }

  @override
  String get libraryMissingRootsAction => 'Settings';

  @override
  String libraryScanRootEmpty(String path) {
    return '$path is empty, library kept as it was';
  }

  @override
  String libraryScanRootTimedOut(String path) {
    return '$path took too long, stopped. If the folder was still being read, the scan finishes by itself when it is done';
  }

  @override
  String libraryScanRootReaderStuck(String path) {
    return '$path was not read: an earlier read is still running. It is tried again automatically when that read finishes; if it never does, restart Kanaru';
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
  String libraryRootTooBroad(String path) {
    return '$path is too broad to be a music folder';
  }

  @override
  String libraryRootWriteFailed(String path) {
    return 'Couldn\'t save $path. See the log for details.';
  }

  @override
  String get libraryUnexpectedError =>
      'Something went wrong. See the log for details.';

  @override
  String get libraryScanFailedDetails => 'See the log for details';

  @override
  String get songsTrackGone => 'That song is no longer in the library.';

  @override
  String get songsShuffleAll => 'Shuffle all';

  @override
  String get queuePlayNext => 'Play next';

  @override
  String get queueAddToQueue => 'Add to queue';

  @override
  String get queueActionsTooltip => 'Queue actions';

  @override
  String queuePlayingNext(String name) {
    return 'Playing next: $name';
  }

  @override
  String queuePlaying(String name) {
    return 'Playing: $name';
  }

  @override
  String queueAddedToQueue(String name) {
    return 'Added to queue: $name';
  }

  @override
  String get sortBy => 'Sort by:';

  @override
  String get sortOrder => 'Order:';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortDescending => 'Descending';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortArtist => 'Artist';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortYear => 'Year';

  @override
  String get sortDateAdded => 'Date added';

  @override
  String get sortDuration => 'Duration';

  @override
  String get sortName => 'Name';

  @override
  String get sortSongCount => 'Songs';

  @override
  String get sortAlbumCount => 'Albums';

  @override
  String get albumsGridView => 'Grid';

  @override
  String get albumsListView => 'List';

  @override
  String get albumsFilterHint => 'Filter albums';

  @override
  String albumsFilterNoMatch(String query) {
    return 'No albums match “$query”';
  }

  @override
  String albumsOwnerSummary(String owner, String albums) {
    return '$owner · $albums';
  }

  @override
  String albumsShownOfTotal(int shown, String albums) {
    return '$shown / $albums';
  }

  @override
  String get albumsSectionEmpty => 'No albums here any more';

  @override
  String get albumsNoRootsMessage => 'Add a music folder in Songs.';

  @override
  String get albumsEmptyTitle => 'No albums yet';

  @override
  String get albumsEmptyMessage =>
      'Songs with an album tag show up here as albums.';

  @override
  String get albumsUnknownArtist => 'Unknown artist';

  @override
  String albumsSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String albumsMinutes(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString min';
  }

  @override
  String get albumsPlayAlbum => 'Play album';

  @override
  String libraryHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$hoursString h $minutes min';
  }

  @override
  String get artistsPlayArtist => 'Play artist';

  @override
  String get albumsPlay => 'Play';

  @override
  String albumsDisc(int number) {
    return 'Disc $number';
  }

  @override
  String get albumsUnknownDisc => 'Unknown disc';

  @override
  String get albumsNotFound => 'Album not found';

  @override
  String get albumsNotFoundMessage =>
      'It may have been removed or renamed by a rescan.';

  @override
  String get artistsNoRootsMessage => 'Add a music folder in Songs.';

  @override
  String get artistsEmptyTitle => 'No artists yet';

  @override
  String get artistsEmptyMessage =>
      'Songs with an artist tag show up here by artist.';

  @override
  String artistsAlbumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String get artistsAlbums => 'Albums';

  @override
  String get artistsAppearsOn => 'Appears on';

  @override
  String get artistsPlay => 'Play';

  @override
  String get artistsNotFound => 'Artist not found';

  @override
  String get artistsNotFoundMessage =>
      'Their songs may have been removed or retagged.';

  @override
  String get genresTitle => 'Genres';

  @override
  String get genresNoRootsMessage => 'Add a music folder in Songs.';

  @override
  String get genresEmptyTitle => 'No genres yet';

  @override
  String get genresEmptyMessage =>
      'Songs with a genre tag show up here by genre.';

  @override
  String get genresAlbums => 'Albums';

  @override
  String get genresNotFound => 'Genre not found';

  @override
  String get genresNotFoundMessage =>
      'Its songs may have been removed or retagged.';

  @override
  String get foldersEmptyTitle => 'No folders yet';

  @override
  String get foldersEmptyMessage => 'Folders with songs show up here.';

  @override
  String get foldersNoRootsMessage => 'Add a music folder in Songs.';

  @override
  String get foldersNotFound => 'Folder not found';

  @override
  String get foldersNotFoundMessage =>
      'It may have been removed or no longer holds songs.';

  @override
  String get foldersTreeView => 'Folder tree';

  @override
  String get foldersFlatView => 'All folders';

  @override
  String get foldersFilterAll => 'All';

  @override
  String foldersSectionFolders(int count) {
    return 'Folders · $count';
  }

  @override
  String foldersSectionSongs(int count) {
    return 'Songs · $count';
  }

  @override
  String foldersCounts(int songs, int folders) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs songs',
      one: '1 song',
    );
    String _temp1 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders subfolders',
      one: '1 subfolder',
      zero: 'no subfolders',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get foldersCreatePlaylist => 'Create playlist';

  @override
  String get foldersEmptyFolder => 'No songs in this folder';

  @override
  String get foldersPlayAllBelow => 'Play all below';

  @override
  String get favoritesEmptyMessage => 'Songs you like will show up here.';

  @override
  String get searchEmptyTitle => 'Search your library';

  @override
  String get searchEmptyMessage => 'Find songs, albums and artists.';

  @override
  String searchResultsTitle(String query) {
    return 'Results for “$query”';
  }

  @override
  String searchShowAll(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Show all ($countString)';
  }

  @override
  String searchShowTop(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Show top $countString';
  }

  @override
  String get searchShowLess => 'Show less';

  @override
  String get searchFailedTitle => 'Search failed';

  @override
  String get searchNoResultsTitle => 'No results';

  @override
  String searchNoResultsMessage(String query) {
    return 'Nothing matches “$query”. Try fewer or shorter words.';
  }

  @override
  String searchMoreSongs(int shown, int total) {
    final intl.NumberFormat shownNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String shownString = shownNumberFormat.format(shown);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Showing the top $shownString of $totalString songs. Add words to narrow it down.';
  }

  @override
  String searchNoResultsNarrowFields(String query) {
    return 'Nothing matches “$query” in the chosen fields. Try turning on more search fields.';
  }

  @override
  String get searchFieldsButton => 'Search fields';

  @override
  String get searchFieldsFiltered => 'Search fields (filtered)';

  @override
  String get searchPresetAll => 'All fields';

  @override
  String get searchPresetTitleOnly => 'Titles only';

  @override
  String get searchFieldTitle => 'Title';

  @override
  String get searchFieldArtist => 'Artist';

  @override
  String get searchFieldAlbum => 'Album';

  @override
  String get searchFieldAlbumArtist => 'Album artist';

  @override
  String get searchFieldGenre => 'Genre';

  @override
  String get searchFieldFileName => 'File name';

  @override
  String get searchFieldComment => 'Description';

  @override
  String get searchCorrectedResultsForPrefix => 'Results for';

  @override
  String get searchHistoryTitle => 'Recent searches';

  @override
  String get searchHistoryRemove => 'Remove from history';

  @override
  String get searchHistoryClearAll => 'Clear all';

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
  String get playerRepeatOff => 'Stop after the last song';

  @override
  String get playerRepeatAll => 'Repeat the whole queue';

  @override
  String get playerRepeatOne => 'Repeat the current song';

  @override
  String get playerRepeatAllShuffled => 'Repeat the whole queue (shuffled)';

  @override
  String playerRepeatTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Repeat $count more times',
      one: 'Repeat 1 more time',
    );
    return '$_temp0';
  }

  @override
  String get playerRepeatFewer => 'One time fewer';

  @override
  String get playerRepeatMore => 'One more time';

  @override
  String get playerMute => 'Mute';

  @override
  String get playerUnmute => 'Unmute';

  @override
  String get playerVolume => 'Volume';

  @override
  String get playerSeek => 'Seek';

  @override
  String get nowPlayingOpen => 'Open Now Playing';

  @override
  String get nowPlayingClose => 'Close Now Playing';

  @override
  String get nowPlayingFavorite => 'Add to favorites';

  @override
  String get nowPlayingAddToPlaylist => 'Add to playlist';

  @override
  String get nowPlayingTabQueue => 'Now playing';

  @override
  String get nowPlayingTabTrack => 'Song';

  @override
  String get nowPlayingBackToTrack => 'Back to the song';

  @override
  String get nowPlayingLyricsOnly => 'Lyrics only';

  @override
  String get nowPlayingViewSplit => 'Split view';

  @override
  String get nowPlayingViewCoverOnly => 'Cover only';

  @override
  String get queueOpen => 'Show now playing list';

  @override
  String get queueTitle => 'Now playing';

  @override
  String queueTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String get queueClear => 'Clear queue';

  @override
  String get queueRemove => 'Remove from queue';

  @override
  String get queueMenuStale => 'The queue changed, so nothing was done';

  @override
  String get queueReorder => 'Drag to reorder';

  @override
  String get queueShowCurrent => 'Jump to current song';

  @override
  String get queueClose => 'Close now playing list';

  @override
  String queueSummary(String tracks, String timeLeft) {
    return '$tracks · $timeLeft';
  }

  @override
  String queueTimeLeftHours(int hours, int minutes) {
    return '$hours h $minutes min left';
  }

  @override
  String queueTimeLeftMinutes(int minutes) {
    return '$minutes min left';
  }

  @override
  String get queueMoreActions => 'More actions';

  @override
  String get settingsLibrary => 'Library';

  @override
  String get settingsRescanLibrary => 'Rescan library';

  @override
  String get settingsFolders => 'Music folders';

  @override
  String get settingsAddFolder => 'Add folder';

  @override
  String get settingsRemoveFolder => 'Remove from library';

  @override
  String get settingsFolderMissing => 'This folder no longer exists';

  @override
  String get settingsRemoveFolderTitle => 'Remove folder from library?';

  @override
  String settingsRemoveFolderBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs will leave the library.',
      one: '1 song will leave the library.',
      zero: 'No songs will leave the library.',
    );
    return '$_temp0 Files on disk are not deleted.';
  }

  @override
  String get settingsRemoveFolderConfirm => 'Remove';

  @override
  String settingsRemoveFolderFailed(String path) {
    return 'Couldn\'t remove $path. See the log for details.';
  }

  @override
  String get settingsRescanOnStartup => 'Rescan when Kanaru opens';

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

  @override
  String get settingsLibraryStats => 'In your library';

  @override
  String settingsStatsTracks(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString tracks',
      one: '$countString track',
    );
    return '$_temp0';
  }

  @override
  String settingsStatsAlbums(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString albums',
      one: '$countString album',
    );
    return '$_temp0';
  }

  @override
  String settingsStatsArtists(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString artists',
      one: '$countString artist',
    );
    return '$_temp0';
  }

  @override
  String settingsStatsGenres(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString genres',
      one: '$countString genre',
    );
    return '$_temp0';
  }

  @override
  String get settingsOpenLogFolder => 'Log files';

  @override
  String get settingsOpenLogFolderHint =>
      'For bug reports. Passwords and tokens are removed before writing.';

  @override
  String get settingsOpenLogFolderButton => 'Open';

  @override
  String get settingsLogFolderUnavailable =>
      'Kanaru has no folder for log files on this system.';

  @override
  String get settingsComingSoon => 'Coming soon';

  @override
  String get settingsOff => 'Off';

  @override
  String get settingsBackupExport => 'Export…';

  @override
  String settingsUnitKb(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString KB';
  }

  @override
  String settingsUnitMb(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '$valueString MB';
  }

  @override
  String settingsUnitSeconds(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString s';
  }

  @override
  String settingsUnitMs(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString ms';
  }

  @override
  String settingsUnitMinutes(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString min';
  }

  @override
  String settingsUnitPercent(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString%';
  }

  @override
  String get settingsAnimations => 'Animations';

  @override
  String get settingsAnimationsHint =>
      'Off: pages, panels, tabs and the sidebar change at once, without motion.';

  @override
  String get settingsColorFromCover => 'Colors from the cover';

  @override
  String get settingsColorFromCoverHint =>
      'Tint the app with the colors of the cover that is playing.';

  @override
  String get settingsWaveformSeekBar => 'Waveform seek bar';

  @override
  String get settingsWaveformSeekBarHint =>
      'Show the shape of the song in the seek bar of Now Playing.';

  @override
  String get settingsFontScale => 'Text size';

  @override
  String get settingsFontScaleHint =>
      'Makes all text in Kanaru smaller or larger.';

  @override
  String get settingsRespectNomedia => 'Skip folders with .nomedia';

  @override
  String get settingsRespectNomediaHint =>
      'Folders that hold a .nomedia file stay out of the library. Applies at the next rescan.';

  @override
  String get settingsSkipHiddenFolders => 'Skip hidden folders';

  @override
  String get settingsSkipHiddenFoldersHint =>
      'Folders whose name starts with a dot stay out of the library. Applies at the next rescan.';

  @override
  String get settingsDuplicatesByFilename => 'Find duplicates by file name';

  @override
  String get settingsDuplicatesByFilenameHint =>
      'Files with the same name count as one song. Applies at the next rescan.';

  @override
  String get settingsM3uPlaylists => 'Read m3u playlists';

  @override
  String get settingsM3uPlaylistsHint =>
      'Add the .m3u files found in the music folders as playlists. Applies at the next rescan.';

  @override
  String get settingsAlbumGrouping => 'Group albums by';

  @override
  String get settingsAlbumGroupingHint =>
      'Songs with the same album title are one album; pick what else must match. Applies at once, the library updates in the background.';

  @override
  String get settingsAlbumGroupTitle => 'Album title';

  @override
  String get settingsAlbumGroupArtist => 'Album artist';

  @override
  String get settingsAlbumGroupYear => 'Year';

  @override
  String get settingsMinFileSize => 'Minimum file size';

  @override
  String get settingsMinFileSizeHint =>
      'Smaller files stay out of the library. Applies at the next rescan.';

  @override
  String get settingsMinDuration => 'Minimum length';

  @override
  String get settingsMinDurationHint =>
      'Shorter songs stay out of the library. Applies at the next rescan.';

  @override
  String get settingsClearCoverCache => 'Clear cover cache';

  @override
  String get settingsClearCoverCacheHint =>
      'Deletes the cover thumbnails; a rescan starts at once and makes them again.';

  @override
  String get settingsClearCoverCacheButton => 'Clear';

  @override
  String get settingsPreferEmbeddedLyrics => 'Prefer embedded lyrics';

  @override
  String get settingsPreferEmbeddedLyricsHint =>
      'Use lyrics stored in the song file before lyric files next to it.';

  @override
  String get settingsGapless => 'Gapless playback';

  @override
  String get settingsGaplessHint =>
      'No silence between songs that follow each other, as on an album.';

  @override
  String get settingsCrossfade => 'Crossfade';

  @override
  String get settingsCrossfadeHint =>
      'How long the end of a song overlaps the start of the next.';

  @override
  String get settingsFadeOnPlay => 'Fade in on play';

  @override
  String get settingsFadeOnPlayHint =>
      'Raise the volume slowly when playback starts.';

  @override
  String get settingsFadeOnPause => 'Fade out on pause';

  @override
  String get settingsFadeOnPauseHint =>
      'Lower the volume slowly before playback pauses.';

  @override
  String get settingsInfiniteQueue => 'Endless queue';

  @override
  String get settingsInfiniteQueueHint =>
      'Next on the last song goes to the first, and Previous on the first song to the last, whatever the repeat mode.';

  @override
  String get settingsListenAfterTime => 'A listen counts after';

  @override
  String get settingsListenAfterTimeHint =>
      'This long, or this share of the song, whichever comes first.';

  @override
  String get settingsListenAfterOr => 'or';

  @override
  String get settingsSidebarTabs => 'Sidebar tabs';

  @override
  String get settingsSidebarTabsHint =>
      'Choose which pages show in the sidebar.';

  @override
  String get settingsTabGenres => 'Genres';

  @override
  String get settingsTabLanguages => 'Languages';

  @override
  String get settingsTrackNumbers => 'Track numbers in albums';

  @override
  String get settingsTrackNumbersHint =>
      'Shows each song\'s number before its cover on an album page.';

  @override
  String get settingsAdvanced => 'Advanced';

  @override
  String get settingsBackupRestore => 'Backup and restore';

  @override
  String get settingsBackupRestoreRow => 'Back up and restore data';

  @override
  String get settingsBackupRestoreHint =>
      'Export and import your settings, playlists and play counts.';

  @override
  String get settingsThemeHint => 'Light, dark, or follow the desktop';

  @override
  String get settingsLanguageHint => 'Language of menus and labels';

  @override
  String get settingsTitleBarHint =>
      'Kanaru\'s own bar with window buttons, the system\'s, or none';

  @override
  String get settingsFoldersHint =>
      'Folders Kanaru looks for music in. Removing one never deletes files.';

  @override
  String get settingsRescanOnStartupHint =>
      'Look for new, changed and removed files in the background each time Kanaru opens';

  @override
  String get settingsRescanLibraryHint =>
      'Look for changes in the music folders now';

  @override
  String get settingsClearListenHistoryHint =>
      'Removes every recorded listen on this device. Can\'t be undone.';

  @override
  String get listenHistoryRecord => 'Record listen history';

  @override
  String get listenHistoryRecordHint =>
      'Kept only on this device. Turning it off keeps what is already recorded.';

  @override
  String get listenHistoryClear => 'Clear listen history';

  @override
  String get listenHistoryClearButton => 'Clear';

  @override
  String get listenHistoryClearTitle => 'Clear all listen history?';

  @override
  String get listenHistoryClearBody =>
      'Every recorded listen, with play counts and last-played times, is removed from Kanaru. This cannot be undone.';

  @override
  String listenHistoryCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Listen history cleared ($count listens)',
      one: 'Listen history cleared (1 listen)',
      zero: 'Listen history cleared',
    );
    return '$_temp0';
  }

  @override
  String get listenHistoryClearFailed => 'Could not clear listen history';

  @override
  String get playbackUnavailableTitle => 'Audio engine not found';

  @override
  String get playbackUnavailableBody =>
      'libmpv could not be loaded. You can browse your library, but playback is turned off.';

  @override
  String get settingsAudioOutputDevice => 'Output device';

  @override
  String get audioDeviceAuto => 'Automatic (system default)';

  @override
  String audioDeviceMissing(String name) {
    return '$name — not available, using Automatic';
  }

  @override
  String get audioDeviceDialogTitle => 'Output device';

  @override
  String get audioDeviceNoneFound => 'No other output devices found';

  @override
  String get audioDeviceOtherOutputs => 'Other outputs';

  @override
  String audioDeviceFailed(String name) {
    return '$name — could not be opened, using Automatic';
  }

  @override
  String get audioDeviceChange => 'Change';

  @override
  String get settingsAudioReplayGain => 'ReplayGain';

  @override
  String get settingsAudioReplayGainHint =>
      'Evens out loudness with the ReplayGain tags in your files. Automatic uses album gain while tracks of one album play in a row, and track gain otherwise.';

  @override
  String get replayGainModeOff => 'Off';

  @override
  String get replayGainModeTrack => 'Track';

  @override
  String get replayGainModeAlbum => 'Album';

  @override
  String get replayGainModeAuto => 'Automatic';

  @override
  String get settingsAudioReplayGainPreamp => 'ReplayGain preamp';

  @override
  String get settingsAudioReplayGainPreampHint =>
      'Gain added on top of the ReplayGain value. Files without ReplayGain tags keep their level.';

  @override
  String settingsAudioDecibels(String value) {
    return '$value dB';
  }

  @override
  String get settingsAudioPreventClipping => 'Prevent clipping';

  @override
  String get settingsAudioPreventClippingHint =>
      'Lower the gain when a boost would distort the loudest peaks.';

  @override
  String get excludedFoldersTitle => 'Excluded folders';

  @override
  String get excludedFoldersHint =>
      'Folders inside your music folders that Kanaru skips. Songs in them leave the library. Files are never deleted.';

  @override
  String get excludedFoldersAdd => 'Exclude folder';

  @override
  String get excludedFoldersRemove => 'Stop excluding';

  @override
  String get excludedFoldersNotInLibrary =>
      'Not inside a music folder, so it has no effect';

  @override
  String get excludedFoldersMissing => 'Folder not found';

  @override
  String get excludedFoldersSameAsRoot =>
      'That is a music folder. Remove it from the folders above instead.';

  @override
  String get excludedFoldersOutsideLibrary =>
      'That folder is not inside a music folder.';

  @override
  String get excludedFoldersAlreadyExcluded =>
      'That folder is already excluded.';

  @override
  String get settingsWatchFolders => 'Watch music folders';

  @override
  String get settingsWatchFoldersHint =>
      'Pick up added, changed and removed files while Kanaru runs, a few seconds after they stop changing';

  @override
  String get settingsWatchFoldersLimit =>
      'Too many folders to watch on this system. Raise fs.inotify.max_user_watches, or use Rescan.';

  @override
  String get historyEmptyMessage => 'Songs you play will show up here.';

  @override
  String historyDayDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String historySince(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'since $dateString';
  }

  @override
  String historyPlayedAt(DateTime date, String time) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString - $time';
  }

  @override
  String get historyDayMenu => 'Day options';

  @override
  String get historyDayCreatePlaylist => 'Create playlist from this day';

  @override
  String get historyDayDelete => 'Remove this day\'s listens';

  @override
  String historyDayPlaylistName(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'History · $dateString';
  }

  @override
  String historyListenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listens',
      one: '1 listen',
    );
    return '$_temp0';
  }

  @override
  String historyNthPlay(int n) {
    return '#$n';
  }

  @override
  String historyNthPlayLabel(int n) {
    return 'Listen number $n';
  }

  @override
  String get historyTrackMissing => 'Not in library';

  @override
  String get historyDeletePlay => 'Remove from history';

  @override
  String historyPlaysDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count listens from history',
      one: 'Removed one listen from history',
    );
    return '$_temp0';
  }

  @override
  String get historyUndo => 'Undo';

  @override
  String get historyDeleteFailed =>
      'Couldn\'t remove the listen. See the log for details.';

  @override
  String get historyRestoreFailed =>
      'Couldn\'t restore the listen. See the log for details.';

  @override
  String get historyCalendar => 'Jump to a day';

  @override
  String get historyRecordingOff => 'Recording listen history is turned off';

  @override
  String get historyUnavailable => 'History is not available';

  @override
  String get historyLoadFailed =>
      'Couldn\'t read the history. See the log for details.';

  @override
  String get historyMore => 'More';

  @override
  String historyOlderYear(int year) {
    return 'Show $year';
  }

  @override
  String get historyRangeToday => 'Today';

  @override
  String get historyRange7Days => '7 days';

  @override
  String get historyRange30Days => '30 days';

  @override
  String get historyRange6Months => '6 months';

  @override
  String get historyRangeYear => '1 year';

  @override
  String get historyRangeAll => 'All time';

  @override
  String get historyRangeCustom => 'Custom';

  @override
  String get historyRangePrevious => 'Previous period';

  @override
  String get historyRangeNext => 'Next period';

  @override
  String get historyRangeDialogTitle => 'Custom range';

  @override
  String get historyRangePickStart => 'Pick the start date';

  @override
  String get historyRangePickEnd => 'Pick the end date';

  @override
  String historyRangeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get historyRangeDayHasListens => 'Has listens';

  @override
  String get historyRangeStartPlaceholder => 'Start date';

  @override
  String get historyRangeEndPlaceholder => 'End date';

  @override
  String historyRangeLabel(String start, String end) {
    return '$start – $end';
  }

  @override
  String historyTopPlayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listens',
      one: '1 listen',
    );
    return '$_temp0';
  }

  @override
  String historyTopCapped(int count) {
    return 'Showing first $count';
  }

  @override
  String get historyPlayAll => 'Play all';

  @override
  String get historyCreatePlaylist => 'Create playlist';

  @override
  String historyTopPlaylistName(String range) {
    return 'Most played · $range';
  }

  @override
  String historyPlaylistCreated(String name) {
    return 'Created playlist $name';
  }

  @override
  String get historyTopEmpty => 'No listens in this range';

  @override
  String get historyShowTrackHistory => 'Song history';

  @override
  String get historyTrackTitle => 'Song history';

  @override
  String historyTrackStats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listens',
      one: '1 listen',
    );
    return '$_temp0';
  }

  @override
  String historyTrackFirst(String date) {
    return 'First $date';
  }

  @override
  String historyTrackLast(String date) {
    return 'Last $date';
  }

  @override
  String historyListened(String duration) {
    return 'listened $duration';
  }

  @override
  String get historyTrackNoPlays => 'No listens yet';

  @override
  String get historyTrackNotFound => 'Song not found';

  @override
  String get historyPlay => 'Play';

  @override
  String get favoritesRemove => 'Remove from favorites';

  @override
  String get favoritesAdded => 'Added to Favorites';

  @override
  String get favoritesRemoved => 'Removed from Favorites';

  @override
  String get playlistM3uImport => 'Import M3U…';

  @override
  String get playlistM3uAllFiles => 'All files';

  @override
  String get playlistM3uImporting => 'Importing playlist…';

  @override
  String playlistM3uImported(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count songs into $name',
      one: 'Imported 1 song into $name',
    );
    return '$_temp0';
  }

  @override
  String playlistM3uImportedNotInLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count are not in your library yet',
      one: '1 is not in your library yet',
    );
    return '$_temp0';
  }

  @override
  String get playlistM3uImportReportTitle => 'Playlist imported';

  @override
  String playlistM3uImportReportSummary(int added, int total) {
    return 'Added $added of $total lines.';
  }

  @override
  String playlistM3uImportReportNotInLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count songs are not in your library yet: they show once their folder is added.',
      one: '1 song is not in your library yet: it shows once its folder is added.',
    );
    return '$_temp0';
  }

  @override
  String playlistM3uImportReportDuplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count repeated lines were merged.',
      one: '1 repeated line was merged.',
    );
    return '$_temp0';
  }

  @override
  String playlistM3uImportReportUnresolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines are not local music files or were not found:',
      one: '1 line is not a local music file or was not found:',
    );
    return '$_temp0';
  }

  @override
  String playlistM3uImportReportTruncated(int limit) {
    return 'Only the first $limit songs were read.';
  }

  @override
  String playlistM3uImportReportLine(int line, String text) {
    return 'Line $line: $text';
  }

  @override
  String playlistM3uImportReportMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more lines',
      one: 'and 1 more line',
    );
    return '$_temp0';
  }

  @override
  String get playlistM3uImportNothingFound =>
      'No local music file of this playlist was found. Nothing was imported.';

  @override
  String get playlistM3uImportTooLarge =>
      'That file is too large to be a playlist.';

  @override
  String get playlistM3uImportFailed =>
      'Couldn\'t read that playlist file. See the log for details.';

  @override
  String get playlistM3uExportAbsolute => 'Export M3U (full paths)…';

  @override
  String get playlistM3uExportRelative => 'Export M3U (relative paths)…';

  @override
  String playlistM3uExported(int count, String file) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved $count songs to $file',
      one: 'Saved 1 song to $file',
    );
    return '$_temp0';
  }

  @override
  String playlistM3uExportSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paths with line breaks were left out',
      one: '1 path with a line break was left out',
    );
    return '$_temp0';
  }

  @override
  String get playlistM3uExportFailed =>
      'Couldn\'t save the playlist file. See the log for details.';

  @override
  String playlistM3uOverwriteTitle(String file) {
    return 'Replace $file?';
  }

  @override
  String get playlistM3uOverwriteConfirm => 'Replace';

  @override
  String get queueSaveAsPlaylist => 'Save queue as playlist';

  @override
  String queueSaveDefaultName(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Queue $dateString';
  }

  @override
  String queueSaved(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved $count songs to $name',
      one: 'Saved 1 song to $name',
    );
    return '$_temp0';
  }

  @override
  String queueSavedSkipped(int count, int skipped, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved $count songs to $name',
      one: 'Saved 1 song to $name',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped left out (not in your library or repeated)',
      one: '1 left out (not in your library or repeated)',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get queueSaveNothing => 'Nothing in the queue is in your library';

  @override
  String get queueHistoryTitle => 'Queues';

  @override
  String get queueHistoryEmptyTitle => 'No queue history yet';

  @override
  String get queueHistoryEmptyMessage =>
      'When you play something new, the queue it replaces is kept here.';

  @override
  String queueHistorySavedAt(DateTime date, DateTime time) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);
    final intl.DateFormat timeDateFormat = intl.DateFormat.Hm(localeName);
    final String timeString = timeDateFormat.format(time);

    return '$dateString · $timeString';
  }

  @override
  String get queueHistoryPlay => 'Play';

  @override
  String get queueHistoryShuffle => 'Shuffle';

  @override
  String get queueHistorySaveAsPlaylist => 'Save as playlist';

  @override
  String queueHistorySavedAsPlaylist(String name) {
    return 'Saved as $name';
  }

  @override
  String get queueHistoryDelete => 'Delete';

  @override
  String get queueHistoryDeleteTitle => 'Delete this queue?';

  @override
  String get queueHistoryDeleteMessage =>
      'It is removed from your queue history. The songs stay in your library.';

  @override
  String get queueHistoryDeleted => 'Queue deleted';

  @override
  String get queueHistoryNothingToPlay =>
      'None of these songs are in your library';

  @override
  String get lyricsNone => 'No lyrics for this song';

  @override
  String get lyricsTab => 'Lyrics';

  @override
  String get coverCacheClearTitle => 'Clear the cover cache?';

  @override
  String get coverCacheClearBody =>
      'Every cover disappears from the library until it is made again. Kanaru rescans right away and makes them in the background, which can take a while for a large library. Colors taken from the covers are kept.';

  @override
  String coverCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count covers. A rescan makes them again.',
      one: 'Deleted 1 cover. A rescan makes them again.',
    );
    return '$_temp0';
  }

  @override
  String get coverCacheClearFailed => 'Could not clear the cover cache';

  @override
  String get genresUnknown => 'Unknown genre';

  @override
  String get separatorsArtistsTitle => 'Split artists';

  @override
  String get separatorsGenresTitle => 'Split genres';

  @override
  String get separatorsArtistsHint =>
      'Applies at once, the library updates in the background.';

  @override
  String get separatorsGenresHint => 'Applies at once, no rescan needed.';

  @override
  String separatorsSummary(int separators, int keepWhole) {
    String _temp0 = intl.Intl.pluralLogic(
      separators,
      locale: localeName,
      other: '$separators separators',
      one: '1 separator',
    );
    String _temp1 = intl.Intl.pluralLogic(
      keepWhole,
      locale: localeName,
      other: '$keepWhole kept whole',
      one: '1 kept whole',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get separatorsEditButton => 'Edit';

  @override
  String separatorsTabSeparators(int count) {
    return 'Separators ($count)';
  }

  @override
  String separatorsTabKeepWhole(int count) {
    return 'Keep whole ($count)';
  }

  @override
  String get separatorsAddSeparatorLabel => 'New separator';

  @override
  String get separatorsAddKeepLabel => 'Name to keep whole';

  @override
  String get separatorsSeparatorHelp =>
      'No need to add spaces around it. Words like feat. split only with a space on each side.';

  @override
  String get separatorsKeepHelpArtist =>
      'Type the name as it is in the tag, any case. AC/DC, for example, stays one artist.';

  @override
  String get separatorsKeepHelpGenre =>
      'Type the name as it is in the tag, any case. Funk/Soul, for example, stays one genre.';

  @override
  String get separatorsAdd => 'Add';

  @override
  String get separatorsErrorEmpty => 'Type something to add';

  @override
  String get separatorsErrorDuplicate => 'Already in the list';

  @override
  String separatorsErrorTooLong(int max) {
    return 'At most $max characters';
  }

  @override
  String separatorsErrorFull(int max) {
    return 'The list holds at most $max entries';
  }

  @override
  String separatorsRemove(String entry) {
    return 'Remove $entry';
  }

  @override
  String get separatorsEmptyList => 'Nothing here yet';

  @override
  String get separatorsEmptySeparators =>
      'Nothing here yet, so nothing is split';

  @override
  String separatorsPage(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String get separatorsReset => 'Restore defaults';

  @override
  String get separatorsResetConfirmTitle => 'Restore defaults?';

  @override
  String get separatorsResetConfirmBody =>
      'Both lists go back to their defaults.';

  @override
  String get separatorsResetConfirm => 'Restore';

  @override
  String get separatorsClose => 'Close';

  @override
  String get scanStatsTracksTitle => 'Songs in the library';

  @override
  String scanStatsTracksOfFiles(int tracks, int files) {
    final intl.NumberFormat tracksNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String tracksString = tracksNumberFormat.format(tracks);
    final intl.NumberFormat filesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String filesString = filesNumberFormat.format(files);

    return '$tracksString of $filesString music files';
  }

  @override
  String get scanStatsNotScanned => 'Not scanned in this session';

  @override
  String get scanStatsLeftOutTitle => 'Left out by scan rules';

  @override
  String scanStatsNomedia(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString files',
      one: '1 file',
    );
    return 'In .nomedia folders: $_temp0';
  }

  @override
  String scanStatsExcluded(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString files',
      one: '1 file',
    );
    return 'In left-out folders: $_temp0';
  }

  @override
  String scanStatsTooSmall(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString files',
      one: '1 file',
    );
    return 'Under minimum size: $_temp0';
  }

  @override
  String scanStatsTooShort(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString files',
      one: '1 file',
    );
    return 'Under minimum length: $_temp0';
  }

  @override
  String get scanStatsTagErrorsTitle => 'Tag errors';

  @override
  String scanStatsTagErrors(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString songs',
      one: '1 song',
      zero: 'No songs',
    );
    return '$_temp0 stored without readable tags';
  }

  @override
  String get scanStatsCoversTitle => 'Cover art';

  @override
  String scanStatsCovers(int images, int tracks) {
    final intl.NumberFormat imagesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String imagesString = imagesNumberFormat.format(images);
    final intl.NumberFormat tracksNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String tracksString = tracksNumberFormat.format(tracks);

    return '$imagesString images made for $tracksString songs with art';
  }

  @override
  String scanStatsSongs(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String scanStatsUnfinishedRoots(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString folders not scanned to the end',
      one: '1 folder not scanned to the end',
    );
    return '$_temp0';
  }

  @override
  String get scanStatsCoversHint =>
      'Kanaru makes these thumbnails itself from the art in the files or the folder. An image repeated in many songs is stored once (by hash).';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String sleepTimerActive(String state) {
    return 'Sleep timer: $state';
  }

  @override
  String sleepTimerMinutes(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get sleepTimerCustom => 'Custom…';

  @override
  String get sleepTimerEndOfTrack => 'End of track';

  @override
  String get sleepTimerEndOfAlbum => 'End of album';

  @override
  String get sleepTimerEndOfQueue => 'End of queue';

  @override
  String sleepTimerLeft(String time) {
    return '$time left';
  }

  @override
  String sleepTimerLeftPaused(String time) {
    return '$time left (paused)';
  }

  @override
  String get sleepTimerAdd => 'Add 5 minutes';

  @override
  String get sleepTimerSubtract => 'Remove 5 minutes';

  @override
  String get sleepTimerPauseCounting => 'Pause counting';

  @override
  String get sleepTimerResumeCounting => 'Resume counting';

  @override
  String get sleepTimerCancel => 'Cancel timer';

  @override
  String get sleepTimerCustomTitle => 'Custom sleep timer';

  @override
  String get sleepTimerCustomLabel => 'Minutes';

  @override
  String sleepTimerCustomInvalid(int min, int max) {
    return 'Enter a whole number from $min to $max';
  }

  @override
  String get sleepTimerStart => 'Start';

  @override
  String get sleepTimerLabelTrack => 'Track';

  @override
  String get sleepTimerLabelAlbum => 'Album';

  @override
  String get sleepTimerLabelQueue => 'Queue';

  @override
  String get navLanguages => 'Languages';

  @override
  String get languagesComingSoonTitle => 'Languages are coming soon';

  @override
  String get languagesComingSoonMessage =>
      'Browsing songs by language is not available yet.';

  @override
  String get languageNameEng => 'English';

  @override
  String get languageNameVie => 'Vietnamese';

  @override
  String get languageNameJpn => 'Japanese';

  @override
  String get languageNameKor => 'Korean';

  @override
  String get languageNameZho => 'Chinese';

  @override
  String get languageNameFra => 'French';

  @override
  String get languageNameDeu => 'German';

  @override
  String get languageNameSpa => 'Spanish';

  @override
  String get languageNameIta => 'Italian';

  @override
  String get languageNameRus => 'Russian';

  @override
  String get languageNamePor => 'Portuguese';

  @override
  String get languageNameTha => 'Thai';

  @override
  String get languageNameInd => 'Indonesian';

  @override
  String get languageNameHin => 'Hindi';

  @override
  String get languageNameAra => 'Arabic';

  @override
  String get languageNameNld => 'Dutch';

  @override
  String get languageNameSwe => 'Swedish';

  @override
  String get languageNamePol => 'Polish';

  @override
  String get languageNameTur => 'Turkish';

  @override
  String get languageNameUkr => 'Ukrainian';

  @override
  String get languageNameCes => 'Czech';

  @override
  String get languageNameEll => 'Greek';

  @override
  String get languageNameFas => 'Persian';

  @override
  String get languageNameRon => 'Romanian';

  @override
  String get languageNameMsa => 'Malay';

  @override
  String get languageNameHeb => 'Hebrew';

  @override
  String get languageNameFin => 'Finnish';

  @override
  String get languageNameDan => 'Danish';

  @override
  String get languageNameNor => 'Norwegian';

  @override
  String get languageNameHun => 'Hungarian';

  @override
  String get languageNameCym => 'Welsh';

  @override
  String get languageNameSlk => 'Slovak';

  @override
  String get languageNameSqi => 'Albanian';

  @override
  String get languageNameHye => 'Armenian';

  @override
  String get languageNameEus => 'Basque';

  @override
  String get languageNameMya => 'Burmese';

  @override
  String get languageNameKat => 'Georgian';

  @override
  String get languageNameIsl => 'Icelandic';

  @override
  String get languageNameMkd => 'Macedonian';

  @override
  String get languageNameMri => 'Maori';

  @override
  String get languageNameBod => 'Tibetan';

  @override
  String get languageNameZxx => 'No lyrics';

  @override
  String get languageNameMul => 'Multiple languages';

  @override
  String get languagesNoRootsMessage => 'Add a music folder in Songs.';

  @override
  String get languagesEmptyTitle => 'No languages yet';

  @override
  String get languagesEmptyMessage =>
      'Songs with a language tag (TLAN in MP3, LANGUAGE in FLAC and Ogg) show up here by language. Rescan your folders to read the tags.';

  @override
  String get languagesAlbums => 'Albums';

  @override
  String get languagesSongs => 'Songs';

  @override
  String get languagesNotFound => 'Language not found';

  @override
  String get languagesNotFoundMessage =>
      'Its songs may have been removed or retagged.';

  @override
  String get albumVariousArtists => 'Various artists';

  @override
  String get inPageSearchHint => 'Filter songs';

  @override
  String get inPageSearchOpen => 'Filter in this page';

  @override
  String get inPageSearchClear => 'Clear filter';

  @override
  String inPageSearchNoMatch(String query) {
    return 'No songs match “$query”';
  }

  @override
  String inPageSearchTooMany(int count) {
    return 'Showing the first $count songs. Type more to narrow it down.';
  }

  @override
  String get homeRecentlyPlayedTitle => 'Recently played';

  @override
  String get homeRecentlyAddedTitle => 'Recently added';

  @override
  String get homeMemoriesTitle => 'Lost memories';

  @override
  String get homeRecentAlbumsTitle => 'Recent albums';

  @override
  String get homeRecentArtistsTitle => 'Recent artists';

  @override
  String get homeMemoriesEmpty => 'No music from this time last year';

  @override
  String get homeAddedWindowAll => 'All';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeScrollBack => 'Scroll back';

  @override
  String get homeScrollForward => 'Scroll forward';

  @override
  String homeAddedWindowDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get homeRecentlyAddedEmpty => 'No songs were added in this period';

  @override
  String get homeRecentAlbumsEmpty => 'No albums played yet';

  @override
  String get homeRecentArtistsEmpty => 'No artists played yet';

  @override
  String get homeLoadFailed => 'Could not load the list';

  @override
  String get homeRetry => 'Retry';

  @override
  String get lyricsTranslationButton => 'Lyrics translation';

  @override
  String get lyricsTranslationButtonLoading =>
      'Lyrics translation: translating';

  @override
  String get lyricsTranslationButtonFailed => 'Lyrics translation: failed';

  @override
  String get lyricsTranslationShow => 'Show translation';

  @override
  String lyricsTranslationTarget(String language) {
    return 'Translate to: $language';
  }

  @override
  String lyricsTranslationTargetDefault(String language) {
    return 'Default ($language)';
  }

  @override
  String get lyricsTranslationDisplayHeader => 'Display style';

  @override
  String get lyricsTranslationDisplayUnder => 'Under each line';

  @override
  String get lyricsTranslationDisplayReplace => 'Replace';

  @override
  String get lyricsTranslationServiceHeader => 'Service';

  @override
  String get lyricsTranslationSaved => 'Translation saved';

  @override
  String lyricsTranslationSavedFrom(String service) {
    return 'Saved from $service';
  }

  @override
  String get lyricsTranslationRetranslate => 'Retranslate';

  @override
  String lyricsTranslationRetranslateWith(String service) {
    return 'Retranslate with $service';
  }

  @override
  String lyricsTranslationSameLanguage(String language) {
    return 'Lyrics are already in $language';
  }

  @override
  String get lyricsTranslationLoading => 'Translating…';

  @override
  String get lyricsTranslationRetry => 'Retry';

  @override
  String get lyricsTranslationFailNetwork =>
      'Could not reach the service. Check your connection.';

  @override
  String get lyricsTranslationFailNoKey =>
      'Add your DeepL API key in Settings.';

  @override
  String get lyricsTranslationFailBadKey =>
      'DeepL rejected the API key. Check it in Settings.';

  @override
  String get lyricsTranslationFailQuota =>
      'The monthly character quota is used up.';

  @override
  String get lyricsTranslationFailRateLimited =>
      'Too many requests. Try again in a moment.';

  @override
  String get lyricsTranslationFailBlocked =>
      'The service blocked the request. Try again later or use the other service.';

  @override
  String get lyricsTranslationFailUnsupportedLanguage =>
      'This service cannot translate into this language.';

  @override
  String get lyricsTranslationFailTooLong =>
      'These lyrics are too long to translate.';

  @override
  String get lyricsTranslationFailServer =>
      'The service had an error. Try again later.';

  @override
  String get lyricsTranslationFailInvalidResponse =>
      'The service sent an answer that could not be read.';

  @override
  String get lyricsTranslationFailEmptyResult =>
      'The service returned no translation.';

  @override
  String get lyricsTranslationFailKeyStoreLocked =>
      'The key store is locked. Unlock it to use your DeepL key.';

  @override
  String get lyricsTranslationFailKeyStoreUnavailable =>
      'The key store is not available, so the DeepL key cannot be read.';

  @override
  String lyricsTranslationAttribution(String service, String language) {
    return 'Translated by $service · $language';
  }

  @override
  String lyricsTranslationButtonLabel(String service, String language) {
    return '$service · $language';
  }

  @override
  String lyricsTranslationUseService(String service) {
    return 'Use $service';
  }

  @override
  String get lyricsTranslationBannerNoKey =>
      'Add your DeepL key in Settings › Advanced.';

  @override
  String get lyricsTranslationBannerBadKey =>
      'DeepL rejected the key. Check the key in Settings › Advanced.';

  @override
  String translationNoticeTitle(String service) {
    return 'Lyrics will be sent to $service';
  }

  @override
  String translationNoticeBody(String service) {
    return 'The text of this song\'s lyrics is sent to $service to be translated. Nothing else is sent.';
  }

  @override
  String get translationNoticeGoogleUnofficial =>
      'Google is used through an unofficial web address, so it may stop working at any time.';

  @override
  String get translationNoticeContinue => 'Continue';

  @override
  String get languageNameZhHans => 'Chinese (Simplified)';

  @override
  String get languageNameZhHant => 'Chinese (Traditional)';

  @override
  String get settingsTranslationService => 'Translation service';

  @override
  String get settingsTranslationServiceGoogleHint =>
      'Free, unofficial service; may stop working. Lyrics text is sent to it when translation is on.';

  @override
  String get settingsTranslationServiceDeeplHint =>
      'Needs your own DeepL API key. Lyrics text is sent to DeepL when translation is on.';

  @override
  String get settingsTranslationTarget => 'Default translation language';

  @override
  String get settingsTranslationTargetHint =>
      'Used for songs that have no language of their own.';

  @override
  String settingsTranslationTargetFollow(String language) {
    return 'Follow app language ($language)';
  }

  @override
  String get deeplKeyTitle => 'DeepL API key';

  @override
  String get deeplKeyNone => 'No key saved';

  @override
  String get deeplKeyAdd => 'Add key';

  @override
  String get deeplKeyEdit => 'Edit';

  @override
  String get deeplKeyClear => 'Clear';

  @override
  String get deeplKeyPlanFree => 'Free';

  @override
  String get deeplKeyPlanPro => 'Pro';

  @override
  String deeplKeyUsage(int used, int limit) {
    final intl.NumberFormat usedNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String usedString = usedNumberFormat.format(used);
    final intl.NumberFormat limitNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return 'Used $usedString of $limitString characters';
  }

  @override
  String deeplKeyUsageNoLimit(int used) {
    final intl.NumberFormat usedNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String usedString = usedNumberFormat.format(used);

    return 'Used $usedString characters';
  }

  @override
  String get deeplKeyUsageHint =>
      'Usage is read from DeepL when you press refresh.';

  @override
  String get deeplKeyRefresh => 'Refresh usage';

  @override
  String get deeplKeyClearTitle => 'Remove the DeepL key?';

  @override
  String get deeplKeyClearBody =>
      'The key is deleted from this computer. Lyrics cannot be translated with DeepL until you add a key again.';

  @override
  String get deeplKeyClearFailed => 'Could not remove the key';

  @override
  String get deeplKeyDialogTitleAdd => 'Add DeepL API key';

  @override
  String get deeplKeyDialogTitleEdit => 'Replace DeepL API key';

  @override
  String get deeplKeyDialogHint =>
      'Paste the key from your DeepL account. DeepL checks it before it is saved.';

  @override
  String get deeplKeyFieldLabel => 'API key';

  @override
  String get deeplKeySave => 'Save';

  @override
  String get deeplKeyBadKey =>
      'DeepL did not accept this key. Check it and try again.';

  @override
  String get deeplKeySaveFailed => 'Could not save the key.';

  @override
  String get deeplKeyReadFailed => 'Could not read the key.';

  @override
  String get deeplKeyKeyringLocked =>
      'Keyring is locked; unlock it, then retry';

  @override
  String get deeplKeyKeyringNoDefault =>
      'No default keyring found; create one (for example in Seahorse or KWallet), then retry';

  @override
  String get deeplKeyKeyringTimeout => 'The keyring is not responding';

  @override
  String get deeplKeyKeyringUnavailable =>
      'The keyring cannot be used right now';

  @override
  String get deeplKeyFileFailed => 'The key file could not be read or written';

  @override
  String deeplKeyFallbackFile(String path) {
    return 'No system keyring found; the key is stored in a file only you can read ($path). Do not share or sync this file.';
  }

  @override
  String get deeplKeyFallbackMemory =>
      'No system keyring found; the key is kept until Kanaru closes.';

  @override
  String get deeplKeyFallbackFixed =>
      'The key file was readable by others; its permissions were fixed. Consider replacing the key.';

  @override
  String get settingsTranslationCache => 'Saved translations';

  @override
  String translationCacheSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0 · $size';
  }

  @override
  String get translationCacheEmpty => 'No saved translations';

  @override
  String get translationCacheClearTitle => 'Clear saved translations?';

  @override
  String get translationCacheClearBody =>
      'The translations saved on this computer are deleted. Your translation settings stay; lyrics are translated again when needed.';

  @override
  String translationCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cleared $count saved translations',
      one: 'Cleared 1 saved translation',
      zero: 'No saved translations to clear',
    );
    return '$_temp0';
  }

  @override
  String get translationCacheClearFailed =>
      'Could not clear saved translations';

  @override
  String settingsUnitBytes(int count) {
    return '$count B';
  }

  @override
  String get settingsClear => 'Clear';

  @override
  String get onlineLyricsNoticeAutoTitle => 'Find lyrics online automatically?';

  @override
  String onlineLyricsNoticeManualTitle(String provider) {
    return 'Search lyrics on $provider?';
  }

  @override
  String onlineLyricsNoticeBody(String hosts) {
    return 'Kanaru sends the song title, artist, album and length to $hosts. No file paths or device details.';
  }

  @override
  String get onlineLyricsNoticeAutoHint =>
      'You can turn it off in Settings › Advanced › Lyrics.';

  @override
  String get onlineLyricsNoticeTurnOn => 'Turn on';

  @override
  String get onlineLyricsNoticeSearch => 'Search';

  @override
  String get lyricsFindOnline => 'Find lyrics online…';

  @override
  String get lyricsPickerTitle => 'Choose lyrics';

  @override
  String lyricsPickerSong(String title, String artist, String duration) {
    return 'Song: $title · $artist · $duration';
  }

  @override
  String get lyricsPickerSearch => 'Search';

  @override
  String get lyricsPickerQueryHint => 'Artist and title';

  @override
  String get lyricsPickerSynced => 'Synced';

  @override
  String get lyricsPickerPlain => 'Plain';

  @override
  String get lyricsPickerInstrumental => 'Instrumental';

  @override
  String get lyricsPickerGoodMatch => 'Good match';

  @override
  String lyricsPickerDelta(int seconds) {
    return '±${seconds}s';
  }

  @override
  String get lyricsPickerEmpty => 'No lyrics found. Try other words.';

  @override
  String lyricsPickerError(String provider) {
    return 'Couldn\'t reach $provider';
  }

  @override
  String get lyricsPickerRetry => 'Retry';

  @override
  String lyricsPickerFooter(String hosts) {
    return 'Results from $hosts · the lyrics you pick are pinned to this song';
  }

  @override
  String get lyricsPickerUse => 'Use these lyrics';

  @override
  String get lyricsPickerNoPreview => 'Select a result to preview its lyrics';

  @override
  String get lyricsPickerNoBody => 'These lyrics can\'t be previewed or used';

  @override
  String get lyricsPickerInstrumentalPreview => 'This song is instrumental';

  @override
  String get lyricsPinned => 'Lyrics pinned to this song';

  @override
  String get lyricsSavedAsLrc => 'Saved as .lrc';

  @override
  String get lyricsNotSavedOutsideLibrary =>
      'Not saved as .lrc: the song is outside your library folders';

  @override
  String get lyricsPickFailed => 'Couldn\'t pin these lyrics';

  @override
  String lyricsPickerNotConsented(String provider) {
    return 'Online lyrics are turned off for $provider. Allow it in Settings.';
  }

  @override
  String lyricsSearching(String provider) {
    return 'Searching $provider…';
  }

  @override
  String get lyricsFindAutomatically => 'Find lyrics automatically';

  @override
  String lyricsNotFound(String provider) {
    return 'No lyrics found on $provider';
  }

  @override
  String get lyricsSearchManually => 'Search manually…';

  @override
  String lyricsOnlineError(String provider) {
    return 'Couldn\'t reach $provider';
  }

  @override
  String lyricsOnlineBusy(String provider) {
    return '$provider is busy. Try again in a moment.';
  }

  @override
  String get lyricsRetry => 'Retry';

  @override
  String get lyricsSkipped => 'Online lyrics turned off for this song';

  @override
  String get lyricsChoose => 'Choose lyrics…';

  @override
  String get lyricsSearchAutomaticallyAgain => 'Search automatically again';

  @override
  String get lyricsInstrumental => 'Instrumental';

  @override
  String lyricsCreditFrom(String provider) {
    return 'Lyrics from $provider';
  }

  @override
  String get lyricsCreditNotSynced => 'not synced';

  @override
  String lyricsCreditMatched(int seconds) {
    return 'matched automatically (off by $seconds s)';
  }

  @override
  String get lyricsCreditMatchedExact => 'matched automatically';

  @override
  String get lyricsCreditPicked => 'picked by you';

  @override
  String get lyricsMenuSearchAgain => 'Search again';

  @override
  String get lyricsMenuChooseOther => 'Choose other lyrics…';

  @override
  String get lyricsMenuNotThese => 'Not these lyrics';

  @override
  String get settingsAutoOnlineLyrics =>
      'Find lyrics online automatically (LRCLIB)';

  @override
  String get settingsAutoOnlineLyricsHint =>
      'While Now Playing is open, for songs without lyrics on this computer. \"Find lyrics online…\" in the song menu always works.';

  @override
  String get settingsWriteLrc => 'Save picked lyrics as .lrc files';

  @override
  String get settingsWriteLrcHint =>
      'When you pick lyrics in Choose lyrics, also writes a .lrc file next to the song if there is none, inside your library folders. Never overwrites.';

  @override
  String get settingsSavedLyrics => 'Saved lyrics';

  @override
  String settingsSavedLyricsSummary(int count, String size, int notFound) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0 · $size · $notFound not found (retried after 14 days)';
  }

  @override
  String get settingsSavedLyricsNone => 'No saved lyrics';

  @override
  String get settingsSavedLyricsClear => 'Clear';

  @override
  String get settingsSavedLyricsClearTitle => 'Clear saved lyrics?';

  @override
  String get settingsSavedLyricsClearBody =>
      'The online lyrics saved on this computer, your picks and the \"not these lyrics\" choices are deleted. .lrc files stay.';

  @override
  String get settingsSavedLyricsCleared => 'Saved lyrics cleared';

  @override
  String get settingsSavedLyricsClearFailed => 'Could not clear saved lyrics';
}
