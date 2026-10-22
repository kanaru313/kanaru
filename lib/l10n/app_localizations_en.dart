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
  String get artistsSongs => 'Songs';

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
  String get genresSongs => 'Songs';

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
  String get foldersSubfolders => 'Folders';

  @override
  String get foldersSongs => 'Songs';

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
  String get nowPlayingOpen => 'Open Now Playing';

  @override
  String get nowPlayingClose => 'Close Now Playing';

  @override
  String get nowPlayingFavorite => 'Add to favorites';

  @override
  String get nowPlayingAddToPlaylist => 'Add to playlist';

  @override
  String get nowPlayingComingSoon => 'Coming soon';

  @override
  String get nowPlayingTabQueue => 'Now playing';

  @override
  String get nowPlayingTabTrack => 'Song';

  @override
  String get nowPlayingBackToTrack => 'Back to the song';

  @override
  String get nowPlayingLyricsOnly => 'Lyrics only';

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
  String get queueReorder => 'Drag to reorder';

  @override
  String get queueShowCurrent => 'Jump to current song';

  @override
  String get queueClose => 'Close now playing list';

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
      'Off: pages and panels switch without motion.';

  @override
  String get settingsColorFromCover => 'Colors from the cover';

  @override
  String get settingsColorFromCoverHint =>
      'Tint the app with the colors of the cover that is playing.';

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
      'Songs with the same album title are one album; pick what else must match. Applies at the next rescan.';

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
      'Covers disappear until the next rescan makes them again.';

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
      'When the queue ends, Next goes back to the first song, and Previous on the first song goes to the last, whatever the repeat mode.';

  @override
  String get settingsListenAfterTime => 'A listen counts after';

  @override
  String get settingsListenAfterTimeHint =>
      'This long, or the share below of the song, whichever comes first.';

  @override
  String get settingsListenAfterShare =>
      'A listen counts after (share of the song)';

  @override
  String get settingsListenAfterShareHint =>
      'This share of the song, or the time above, whichever comes first.';

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
      'Show each song\'s number on an album page.';

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
}
