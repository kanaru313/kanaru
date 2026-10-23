// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Kanaru';

  @override
  String get navHome => 'Trang chủ';

  @override
  String get navSongs => 'Bài hát';

  @override
  String get navAlbums => 'Album';

  @override
  String get navArtists => 'Nghệ sĩ';

  @override
  String get navFolders => 'Thư mục';

  @override
  String get navFavorites => 'Yêu thích';

  @override
  String get navHistory => 'Lịch sử';

  @override
  String get navSearch => 'Tìm kiếm';

  @override
  String get navSettings => 'Cài đặt';

  @override
  String get sidebarPlaylists => 'Playlist';

  @override
  String get sidebarNoPlaylists => 'Chưa có playlist nào';

  @override
  String get sidebarNewPlaylist => 'Playlist mới';

  @override
  String get sidebarExpand => 'Mở rộng';

  @override
  String get sidebarCollapse => 'Thu gọn';

  @override
  String get sidebarShrink => 'Thu gọn thanh bên';

  @override
  String get sidebarGrow => 'Mở rộng thanh bên';

  @override
  String get playlistDefaultName => 'Playlist mới';

  @override
  String get playlistCreateTitle => 'Tạo playlist';

  @override
  String get playlistCreateConfirm => 'Tạo';

  @override
  String get playlistRename => 'Đổi tên';

  @override
  String get playlistRenameTitle => 'Đổi tên playlist';

  @override
  String get playlistNameLabel => 'Tên';

  @override
  String get playlistDelete => 'Xoá playlist';

  @override
  String playlistDeleteTitle(String name) {
    return 'Xoá “$name”?';
  }

  @override
  String playlistDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Playlist có $count bài.',
      zero: 'Playlist chưa có bài nào.',
    );
    return '$_temp0 Các bài vẫn còn trong thư viện.';
  }

  @override
  String get playlistDeleteConfirm => 'Xoá';

  @override
  String get playlistActions => 'Thao tác playlist';

  @override
  String playlistTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bài',
      zero: 'Chưa có bài',
    );
    return '$_temp0';
  }

  @override
  String get playlistEmptyTitle => 'Playlist trống';

  @override
  String get playlistEmptyMessage =>
      'Thêm bài từ menu của bài hát, album hoặc nghệ sĩ.';

  @override
  String get playlistsEmptyMessage => 'Tạo playlist để xếp bài theo ý bạn.';

  @override
  String get playlistNotFound => 'Không tìm thấy playlist';

  @override
  String get playlistNotFoundMessage => 'Có thể playlist đã bị xoá.';

  @override
  String get playlistNotInLibrary => 'Không có trong thư viện';

  @override
  String get playlistRemoveEntry => 'Bỏ khỏi playlist';

  @override
  String get playlistReorder => 'Kéo để sắp xếp lại';

  @override
  String get playlistAddTo => 'Thêm vào playlist…';

  @override
  String get playlistPickerTitle => 'Thêm vào playlist';

  @override
  String get playlistPickerNew => 'Playlist mới…';

  @override
  String playlistAdded(String name, String playlist) {
    return 'Đã thêm vào $playlist: $name';
  }

  @override
  String playlistAddedSkipped(int added, int skipped, String playlist) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Đã thêm $added bài vào $playlist',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped bài đã có sẵn',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String playlistAlreadyIn(String name, String playlist) {
    return 'Đã có trong $playlist: $name';
  }

  @override
  String get playlistSaveFailed =>
      'Không lưu được playlist. Xem log để biết chi tiết.';

  @override
  String get playlistTrackNotInLibrary =>
      'Bài này không có trong thư viện nên không thêm vào playlist được.';

  @override
  String get topBarBack => 'Quay lại';

  @override
  String get topBarForward => 'Tiến tới';

  @override
  String get topBarSearchHint => 'Tìm bài hát, album, nghệ sĩ';

  @override
  String get windowMinimize => 'Thu nhỏ';

  @override
  String get windowMaximize => 'Phóng to';

  @override
  String get windowRestore => 'Khôi phục';

  @override
  String get windowClose => 'Đóng';

  @override
  String get homeGreetingMorning => 'Chào buổi sáng';

  @override
  String get homeGreetingAfternoon => 'Chào buổi chiều';

  @override
  String get homeGreetingEvening => 'Chào buổi tối';

  @override
  String get homeSubtitle => 'Nghe tiếp những gì bạn yêu thích';

  @override
  String get libraryEmptyTitle => 'Thư viện của bạn đang trống';

  @override
  String get libraryEmptyMessage =>
      'Thêm thư mục nhạc để bắt đầu tạo thư viện.';

  @override
  String get onboardingTitle => 'Chào mừng đến với Kanaru';

  @override
  String get onboardingMessage =>
      'Chọn các thư mục chứa nhạc của bạn. Kanaru sẽ quét chúng và tạo thư viện.';

  @override
  String get onboardingSuggested => 'Gợi ý';

  @override
  String get onboardingNoFolders => 'Chưa chọn thư mục nào.';

  @override
  String get onboardingAddFolder => 'Thêm thư mục…';

  @override
  String get onboardingRemoveFolder => 'Bỏ thư mục này';

  @override
  String get onboardingLater => 'Để sau';

  @override
  String get onboardingStart => 'Bắt đầu';

  @override
  String get libraryUnavailableTitle => 'Không mở được thư viện';

  @override
  String get libraryUnavailableMessage =>
      'Bạn vẫn có thể phát nhạc. Xem chi tiết trong nhật ký.';

  @override
  String get libraryChooseFolder => 'Chọn thư mục nhạc';

  @override
  String get libraryNoTracksTitle => 'Không tìm thấy bài nào';

  @override
  String get libraryNoTracksMessage =>
      'Thêm nhạc vào các thư mục rồi quét lại.';

  @override
  String get libraryRescan => 'Quét lại';

  @override
  String get libraryShuffle => 'Phát ngẫu nhiên';

  @override
  String get libraryShowArtist => 'Xem nghệ sĩ';

  @override
  String get libraryShowAlbum => 'Xem album';

  @override
  String get libraryShowInFileManager => 'Mở trong trình quản lý tệp';

  @override
  String get libraryFileManagerFailed => 'Không mở được trình quản lý tệp';

  @override
  String get libraryTrackGone => 'Bài này không còn trong thư viện';

  @override
  String get libraryNoAlbumToShow => 'Bài này không có album';

  @override
  String get libraryNoArtistToShow => 'Bài này không có nghệ sĩ';

  @override
  String get libraryChooseArtist => 'Chọn nghệ sĩ';

  @override
  String get libraryKeysUpdatingTitle => 'Đang cập nhật thư viện…';

  @override
  String get libraryKeysUpdatingMessage =>
      'Đang sắp xếp nhạc của bạn. Bạn vẫn có thể phát nhạc.';

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

    return 'Đang tạo ảnh bìa… $doneString / $totalString';
  }

  @override
  String get libraryScanDiscovering => 'Đang tìm file nhạc…';

  @override
  String libraryScanReading(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Đang đọc tag $doneString / $totalString';
  }

  @override
  String get libraryScanDoneTitle => 'Đã quét xong';

  @override
  String get libraryScanWarningTitle => 'Đã quét xong, có cảnh báo';

  @override
  String get libraryScanFailedTitle => 'Quét thất bại';

  @override
  String get libraryScanNoChanges => 'Không có thay đổi';

  @override
  String libraryScanAdded(int count) {
    return '$count bài mới';
  }

  @override
  String libraryScanUpdated(int count) {
    return '$count bài đã cập nhật';
  }

  @override
  String libraryScanRemoved(int count) {
    return '$count bài đã xoá';
  }

  @override
  String libraryScanFailedTags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file không đọc được tag',
    );
    return '$_temp0';
  }

  @override
  String libraryScanUndecodableNames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã bỏ qua $count file hoặc thư mục: tên không phải UTF-8 hợp lệ',
    );
    return '$_temp0';
  }

  @override
  String libraryScanRootMissing(String path) {
    return 'Không tìm thấy $path';
  }

  @override
  String libraryMissingRoots(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count thư mục nhạc không còn tồn tại',
      one: 'Không tìm thấy thư mục nhạc: $path',
    );
    return '$_temp0';
  }

  @override
  String get libraryMissingRootsAction => 'Cài đặt';

  @override
  String libraryScanRootEmpty(String path) {
    return '$path đang trống, giữ nguyên thư viện';
  }

  @override
  String libraryScanRootTimedOut(String path) {
    return '$path mất quá nhiều thời gian nên đã dừng. Nếu thư mục vẫn đang được đọc, việc quét sẽ tự hoàn tất khi đọc xong';
  }

  @override
  String libraryScanRootReaderStuck(String path) {
    return 'Chưa đọc $path: một lần đọc trước đó vẫn đang chạy. Kanaru sẽ tự thử lại khi lần đọc đó xong; nếu nó không bao giờ xong, hãy khởi động lại Kanaru';
  }

  @override
  String libraryRootNotFound(String path) {
    return 'Không tìm thấy $path';
  }

  @override
  String libraryRootNotDirectory(String path) {
    return '$path không phải thư mục';
  }

  @override
  String libraryRootDuplicate(String path) {
    return '$path đã được thêm';
  }

  @override
  String libraryRootNested(String path) {
    return '$path nằm trong hoặc chứa một thư mục đã thêm';
  }

  @override
  String get libraryRootUnavailable => 'Thư viện không khả dụng';

  @override
  String libraryRootTooBroad(String path) {
    return '$path quá rộng để làm thư mục nhạc';
  }

  @override
  String libraryRootWriteFailed(String path) {
    return 'Không lưu được $path. Xem chi tiết trong nhật ký.';
  }

  @override
  String get libraryUnexpectedError =>
      'Đã xảy ra lỗi. Xem chi tiết trong nhật ký.';

  @override
  String get libraryScanFailedDetails => 'Xem chi tiết trong nhật ký';

  @override
  String get songsTrackGone => 'Bài hát này không còn trong thư viện.';

  @override
  String get songsShuffleAll => 'Phát ngẫu nhiên tất cả';

  @override
  String get queuePlayNext => 'Phát tiếp theo';

  @override
  String get queueAddToQueue => 'Thêm vào hàng đợi';

  @override
  String get queueActionsTooltip => 'Thao tác hàng đợi';

  @override
  String queuePlayingNext(String name) {
    return 'Phát tiếp theo: $name';
  }

  @override
  String queuePlaying(String name) {
    return 'Đang phát: $name';
  }

  @override
  String queueAddedToQueue(String name) {
    return 'Đã thêm vào hàng đợi: $name';
  }

  @override
  String get sortBy => 'Sắp xếp:';

  @override
  String get sortOrder => 'Thứ tự:';

  @override
  String get sortAscending => 'Tăng dần';

  @override
  String get sortDescending => 'Giảm dần';

  @override
  String get sortTitle => 'Tên';

  @override
  String get sortArtist => 'Nghệ sĩ';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortYear => 'Năm';

  @override
  String get sortDateAdded => 'Ngày thêm';

  @override
  String get sortDuration => 'Thời lượng';

  @override
  String get sortName => 'Tên';

  @override
  String get sortSongCount => 'Số bài';

  @override
  String get sortAlbumCount => 'Số album';

  @override
  String get albumsGridView => 'Lưới';

  @override
  String get albumsListView => 'Danh sách';

  @override
  String get albumsNoRootsMessage => 'Thêm thư mục nhạc ở mục Bài hát.';

  @override
  String get albumsEmptyTitle => 'Chưa có album';

  @override
  String get albumsEmptyMessage =>
      'Bài hát có tag album sẽ hiện ở đây theo album.';

  @override
  String get albumsUnknownArtist => 'Nghệ sĩ không rõ';

  @override
  String albumsSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bài',
    );
    return '$_temp0';
  }

  @override
  String get albumsPlay => 'Phát';

  @override
  String albumsDisc(int number) {
    return 'Đĩa $number';
  }

  @override
  String get albumsUnknownDisc => 'Đĩa không rõ';

  @override
  String get albumsNotFound => 'Không tìm thấy album';

  @override
  String get albumsNotFoundMessage =>
      'Có thể album đã bị xoá hoặc đổi tên sau lần quét lại.';

  @override
  String get artistsNoRootsMessage => 'Thêm thư mục nhạc ở mục Bài hát.';

  @override
  String get artistsEmptyTitle => 'Chưa có nghệ sĩ';

  @override
  String get artistsEmptyMessage =>
      'Bài hát có tag nghệ sĩ sẽ hiện ở đây theo nghệ sĩ.';

  @override
  String artistsAlbumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count album',
    );
    return '$_temp0';
  }

  @override
  String get artistsAlbums => 'Album';

  @override
  String get artistsSongs => 'Bài hát';

  @override
  String get artistsAppearsOn => 'Xuất hiện trong';

  @override
  String get artistsPlay => 'Phát';

  @override
  String get artistsNotFound => 'Không tìm thấy nghệ sĩ';

  @override
  String get artistsNotFoundMessage =>
      'Có thể bài hát của nghệ sĩ đã bị xoá hoặc đổi tag.';

  @override
  String get genresTitle => 'Thể loại';

  @override
  String get genresNoRootsMessage => 'Thêm thư mục nhạc ở mục Bài hát.';

  @override
  String get genresEmptyTitle => 'Chưa có thể loại';

  @override
  String get genresEmptyMessage =>
      'Bài hát có tag thể loại sẽ hiện ở đây theo thể loại.';

  @override
  String get genresAlbums => 'Album';

  @override
  String get genresSongs => 'Bài hát';

  @override
  String get genresNotFound => 'Không tìm thấy thể loại';

  @override
  String get genresNotFoundMessage => 'Có thể bài hát đã bị xoá hoặc đổi tag.';

  @override
  String get foldersEmptyTitle => 'Chưa có thư mục';

  @override
  String get foldersEmptyMessage => 'Thư mục có bài hát sẽ hiện ở đây.';

  @override
  String get foldersNoRootsMessage => 'Thêm thư mục nhạc ở mục Bài hát.';

  @override
  String get foldersNotFound => 'Không tìm thấy thư mục';

  @override
  String get foldersNotFoundMessage =>
      'Có thể thư mục đã bị xoá hoặc không còn bài hát.';

  @override
  String get foldersTreeView => 'Cây thư mục';

  @override
  String get foldersFlatView => 'Tất cả thư mục';

  @override
  String get foldersSubfolders => 'Thư mục';

  @override
  String get foldersSongs => 'Bài hát';

  @override
  String foldersCounts(int songs, int folders) {
    return '$songs bài, $folders thư mục con';
  }

  @override
  String get foldersCreatePlaylist => 'Tạo playlist';

  @override
  String get foldersEmptyFolder => 'Thư mục này không có bài hát';

  @override
  String get favoritesEmptyMessage => 'Bài hát bạn thích sẽ hiện ở đây.';

  @override
  String get searchEmptyTitle => 'Tìm trong thư viện';

  @override
  String get searchEmptyMessage => 'Tìm bài hát, album và nghệ sĩ.';

  @override
  String searchResultsTitle(String query) {
    return 'Kết quả cho “$query”';
  }

  @override
  String searchShowAll(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Xem tất cả ($countString)';
  }

  @override
  String searchShowTop(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Xem $countString bài đầu';
  }

  @override
  String get searchShowLess => 'Thu gọn';

  @override
  String get searchFailedTitle => 'Không tìm được';

  @override
  String get searchNoResultsTitle => 'Không có kết quả';

  @override
  String searchNoResultsMessage(String query) {
    return 'Không tìm thấy kết quả cho “$query”. Thử bớt từ hoặc gõ ngắn hơn.';
  }

  @override
  String searchMoreSongs(int shown, int total) {
    final intl.NumberFormat shownNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String shownString = shownNumberFormat.format(shown);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Đang hiện $shownString bài đầu trong $totalString bài. Thêm từ để thu hẹp kết quả.';
  }

  @override
  String playerPlaybackError(String title) {
    return 'Không phát được $title';
  }

  @override
  String get playerPlay => 'Phát';

  @override
  String get playerPause => 'Tạm dừng';

  @override
  String get playerPrevious => 'Bài trước';

  @override
  String get playerNext => 'Bài tiếp';

  @override
  String get playerShuffle => 'Phát ngẫu nhiên';

  @override
  String get playerRepeatOff => 'Không lặp';

  @override
  String get playerRepeatAll => 'Lặp tất cả';

  @override
  String get playerRepeatOne => 'Lặp một bài';

  @override
  String get playerMute => 'Tắt tiếng';

  @override
  String get playerUnmute => 'Bật tiếng';

  @override
  String get playerVolume => 'Âm lượng';

  @override
  String get playerSeek => 'Tua';

  @override
  String get nowPlayingOpen => 'Mở màn hình đang phát';

  @override
  String get nowPlayingClose => 'Đóng màn hình đang phát';

  @override
  String get nowPlayingFavorite => 'Thêm vào yêu thích';

  @override
  String get nowPlayingAddToPlaylist => 'Thêm vào playlist';

  @override
  String get nowPlayingTabQueue => 'Đang phát';

  @override
  String get nowPlayingTabTrack => 'Bài hát';

  @override
  String get nowPlayingBackToTrack => 'Quay lại bài hát';

  @override
  String get nowPlayingLyricsOnly => 'Chỉ hiện lời bài hát';

  @override
  String get queueOpen => 'Mở danh sách đang phát';

  @override
  String get queueTitle => 'Đang phát';

  @override
  String queueTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bài',
    );
    return '$_temp0';
  }

  @override
  String get queueClear => 'Xoá hàng đợi';

  @override
  String get queueRemove => 'Xoá khỏi hàng đợi';

  @override
  String get queueReorder => 'Kéo để sắp xếp lại';

  @override
  String get queueShowCurrent => 'Tới bài đang phát';

  @override
  String get queueClose => 'Đóng danh sách đang phát';

  @override
  String get settingsLibrary => 'Thư viện';

  @override
  String get settingsRescanLibrary => 'Quét lại thư viện';

  @override
  String get settingsFolders => 'Thư mục nhạc';

  @override
  String get settingsAddFolder => 'Thêm thư mục';

  @override
  String get settingsRemoveFolder => 'Bỏ khỏi thư viện';

  @override
  String get settingsFolderMissing => 'Thư mục này không còn tồn tại';

  @override
  String get settingsRemoveFolderTitle => 'Bỏ thư mục khỏi thư viện?';

  @override
  String settingsRemoveFolderBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bài sẽ bị gỡ khỏi thư viện.',
      zero: 'Không có bài nào bị gỡ khỏi thư viện.',
    );
    return '$_temp0 File nhạc trên đĩa không bị xoá.';
  }

  @override
  String get settingsRemoveFolderConfirm => 'Bỏ';

  @override
  String settingsRemoveFolderFailed(String path) {
    return 'Không bỏ được $path. Xem chi tiết trong nhật ký.';
  }

  @override
  String get settingsRescanOnStartup => 'Quét lại khi mở Kanaru';

  @override
  String get settingsAppearance => 'Giao diện';

  @override
  String get settingsTheme => 'Chủ đề';

  @override
  String get settingsThemeSystem => 'Hệ thống';

  @override
  String get settingsThemeLight => 'Sáng';

  @override
  String get settingsThemeDark => 'Tối';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

  @override
  String get settingsLanguageSystem => 'Hệ thống';

  @override
  String get settingsTitleBar => 'Thanh tiêu đề';

  @override
  String get settingsTitleBarKanaru => 'Kanaru';

  @override
  String get settingsTitleBarSystem => 'Hệ thống';

  @override
  String get settingsTitleBarNone => 'Không có';

  @override
  String get settingsRestartRequired => 'Áp dụng sau khi khởi động lại';

  @override
  String settingsReadOnly(String path) {
    return 'Không lưu được cài đặt trong phiên này ($path)';
  }

  @override
  String get settingsAbout => 'Giới thiệu';

  @override
  String get settingsVersion => 'Phiên bản';

  @override
  String get settingsLicense => 'Giấy phép';

  @override
  String get settingsSourceCode => 'Mã nguồn';

  @override
  String settingsOpenFailed(String target) {
    return 'Không mở được $target';
  }

  @override
  String get settingsLibraryStats => 'Trong thư viện';

  @override
  String settingsStatsTracks(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString bài';
  }

  @override
  String settingsStatsAlbums(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString album';
  }

  @override
  String settingsStatsArtists(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString nghệ sĩ';
  }

  @override
  String settingsStatsGenres(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString thể loại';
  }

  @override
  String get settingsOpenLogFolder => 'File log';

  @override
  String get settingsOpenLogFolderHint =>
      'Để đính kèm khi báo lỗi. Mật khẩu và token đã được che trước khi ghi.';

  @override
  String get settingsOpenLogFolderButton => 'Mở';

  @override
  String get settingsLogFolderUnavailable =>
      'Kanaru không có thư mục log trên hệ thống này.';

  @override
  String get settingsComingSoon => 'Sắp có';

  @override
  String get settingsOff => 'Tắt';

  @override
  String get settingsBackupExport => 'Xuất…';

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

    return '$countString giây';
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

    return '$countString phút';
  }

  @override
  String settingsUnitPercent(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString%';
  }

  @override
  String get settingsAnimations => 'Hiệu ứng chuyển động';

  @override
  String get settingsAnimationsHint =>
      'Tắt: trang và bảng chuyển không có chuyển động.';

  @override
  String get settingsColorFromCover => 'Màu theo ảnh bìa';

  @override
  String get settingsColorFromCoverHint =>
      'Phủ màu của ảnh bìa đang phát lên giao diện.';

  @override
  String get settingsFontScale => 'Cỡ chữ';

  @override
  String get settingsFontScaleHint =>
      'Làm mọi chữ trong Kanaru nhỏ hơn hoặc lớn hơn.';

  @override
  String get settingsRespectNomedia => 'Bỏ qua thư mục có .nomedia';

  @override
  String get settingsRespectNomediaHint =>
      'Thư mục có file .nomedia không vào thư viện. Có hiệu lực ở lần quét sau.';

  @override
  String get settingsDuplicatesByFilename => 'Tìm bài trùng theo tên file';

  @override
  String get settingsDuplicatesByFilenameHint =>
      'File trùng tên được tính là một bài. Có hiệu lực ở lần quét sau.';

  @override
  String get settingsM3uPlaylists => 'Đọc playlist m3u';

  @override
  String get settingsM3uPlaylistsHint =>
      'Thêm các file .m3u trong thư mục nhạc thành playlist. Có hiệu lực ở lần quét sau.';

  @override
  String get settingsAlbumGrouping => 'Nhóm album theo';

  @override
  String get settingsAlbumGroupingHint =>
      'Bài cùng tên album là một album; chọn thêm điều kiện phải trùng. Có hiệu lực ở lần quét sau.';

  @override
  String get settingsAlbumGroupTitle => 'Tên album';

  @override
  String get settingsAlbumGroupArtist => 'Album artist';

  @override
  String get settingsAlbumGroupYear => 'Năm';

  @override
  String get settingsMinFileSize => 'Kích thước file tối thiểu';

  @override
  String get settingsMinFileSizeHint =>
      'File nhỏ hơn không vào thư viện. Có hiệu lực ở lần quét sau.';

  @override
  String get settingsMinDuration => 'Thời lượng tối thiểu';

  @override
  String get settingsMinDurationHint =>
      'Bài ngắn hơn không vào thư viện. Có hiệu lực ở lần quét sau.';

  @override
  String get settingsClearCoverCache => 'Xoá cache ảnh bìa';

  @override
  String get settingsClearCoverCacheHint =>
      'Xoá ảnh bìa đã tạo; quét lại chạy ngay và tạo lại chúng.';

  @override
  String get settingsClearCoverCacheButton => 'Xoá';

  @override
  String get settingsPreferEmbeddedLyrics => 'Ưu tiên lời nhúng trong file';

  @override
  String get settingsPreferEmbeddedLyricsHint =>
      'Dùng lời lưu trong file nhạc trước các file lời đặt cạnh nó.';

  @override
  String get settingsGapless => 'Phát liền mạch (gapless)';

  @override
  String get settingsGaplessHint =>
      'Không có khoảng lặng giữa các bài nối tiếp nhau, như trong một album.';

  @override
  String get settingsCrossfade => 'Chuyển bài mờ dần (crossfade)';

  @override
  String get settingsCrossfadeHint =>
      'Thời gian cuối bài này chồng lên đầu bài kế tiếp.';

  @override
  String get settingsFadeOnPlay => 'Tăng dần âm lượng khi phát';

  @override
  String get settingsFadeOnPlayHint => 'Tăng âm lượng từ từ khi bắt đầu phát.';

  @override
  String get settingsFadeOnPause => 'Giảm dần âm lượng khi tạm dừng';

  @override
  String get settingsFadeOnPauseHint =>
      'Giảm âm lượng từ từ trước khi tạm dừng.';

  @override
  String get settingsInfiniteQueue => 'Hàng đợi vô hạn';

  @override
  String get settingsInfiniteQueueHint =>
      'Bài tiếp ở bài cuối về bài đầu, Bài trước ở bài đầu tới bài cuối, bất kể chế độ lặp.';

  @override
  String get settingsListenAfterTime => 'Một lượt nghe được tính sau';

  @override
  String get settingsListenAfterTimeHint =>
      'Khoảng thời gian này, hoặc tỉ lệ bên dưới của bài, tuỳ điều kiện nào đến trước.';

  @override
  String get settingsListenAfterShare =>
      'Một lượt nghe được tính sau (tỉ lệ của bài)';

  @override
  String get settingsListenAfterShareHint =>
      'Tỉ lệ này của bài, hoặc thời gian bên trên, tuỳ điều kiện nào đến trước.';

  @override
  String get settingsSidebarTabs => 'Tab thanh bên';

  @override
  String get settingsSidebarTabsHint => 'Chọn các trang hiện ở thanh bên.';

  @override
  String get settingsTabGenres => 'Thể loại';

  @override
  String get settingsTabLanguages => 'Ngôn ngữ bài hát';

  @override
  String get settingsTrackNumbers => 'Số thứ tự bài trong album';

  @override
  String get settingsTrackNumbersHint =>
      'Bật: số thứ tự của từng bài trên trang album. Tắt: ảnh bìa của bài.';

  @override
  String get settingsAdvanced => 'Nâng cao';

  @override
  String get settingsBackupRestore => 'Sao lưu & khôi phục';

  @override
  String get settingsBackupRestoreRow => 'Sao lưu và khôi phục dữ liệu';

  @override
  String get settingsBackupRestoreHint =>
      'Xuất và nhập cài đặt, playlist và lượt nghe.';

  @override
  String get settingsThemeHint => 'Sáng, tối hoặc theo hệ thống';

  @override
  String get settingsLanguageHint => 'Ngôn ngữ của menu và nhãn';

  @override
  String get settingsTitleBarHint =>
      'Thanh riêng của Kanaru có nút cửa sổ, thanh của hệ thống, hoặc không có';

  @override
  String get settingsFoldersHint =>
      'Thư mục Kanaru tìm nhạc. Bỏ một thư mục không xoá file nào.';

  @override
  String get settingsRescanOnStartupHint =>
      'Mỗi lần mở Kanaru, tìm file mới, đã sửa và đã xoá trong nền';

  @override
  String get settingsRescanLibraryHint =>
      'Tìm thay đổi trong các thư mục nhạc ngay bây giờ';

  @override
  String get settingsClearListenHistoryHint =>
      'Xoá mọi lượt nghe đã ghi trên máy này. Không hoàn tác được.';

  @override
  String get listenHistoryRecord => 'Ghi lịch sử nghe';

  @override
  String get listenHistoryRecordHint =>
      'Chỉ lưu trên máy này. Tắt thì giữ lại những gì đã ghi.';

  @override
  String get listenHistoryClear => 'Xoá lịch sử nghe';

  @override
  String get listenHistoryClearButton => 'Xoá';

  @override
  String get listenHistoryClearTitle => 'Xoá toàn bộ lịch sử nghe?';

  @override
  String get listenHistoryClearBody =>
      'Mọi lượt nghe đã ghi, cùng số lượt và lần nghe cuối, sẽ bị xoá khỏi Kanaru. Không thể hoàn tác.';

  @override
  String listenHistoryCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã xoá lịch sử nghe ($count lượt)',
      zero: 'Đã xoá lịch sử nghe',
    );
    return '$_temp0';
  }

  @override
  String get listenHistoryClearFailed => 'Không xoá được lịch sử nghe';

  @override
  String get playbackUnavailableTitle => 'Không tìm thấy trình phát âm thanh';

  @override
  String get playbackUnavailableBody =>
      'Không tải được libmpv. Bạn vẫn xem được thư viện nhạc, nhưng tính năng phát nhạc đã bị tắt.';

  @override
  String get settingsAudioOutputDevice => 'Thiết bị đầu ra';

  @override
  String get audioDeviceAuto => 'Tự động (theo hệ thống)';

  @override
  String audioDeviceMissing(String name) {
    return '$name — không có, đang dùng Tự động';
  }

  @override
  String get audioDeviceDialogTitle => 'Thiết bị đầu ra';

  @override
  String get audioDeviceNoneFound => 'Không tìm thấy thiết bị đầu ra nào khác';

  @override
  String get audioDeviceOtherOutputs => 'Đầu ra khác';

  @override
  String audioDeviceFailed(String name) {
    return '$name — không mở được, đang dùng Tự động';
  }

  @override
  String get audioDeviceChange => 'Đổi';

  @override
  String get settingsAudioReplayGain => 'ReplayGain';

  @override
  String get settingsAudioReplayGainHint =>
      'Cân bằng độ lớn theo thẻ ReplayGain trong file. Tự động dùng mức theo album khi các bài cùng album phát liền nhau, còn lại dùng mức theo bài.';

  @override
  String get replayGainModeOff => 'Tắt';

  @override
  String get replayGainModeTrack => 'Theo bài';

  @override
  String get replayGainModeAlbum => 'Theo album';

  @override
  String get replayGainModeAuto => 'Tự động';

  @override
  String get settingsAudioReplayGainPreamp => 'Tiền khuếch đại ReplayGain';

  @override
  String get settingsAudioReplayGainPreampHint =>
      'Mức tăng cộng thêm vào giá trị ReplayGain. File không có thẻ ReplayGain giữ nguyên âm lượng.';

  @override
  String settingsAudioDecibels(String value) {
    return '$value dB';
  }

  @override
  String get settingsAudioPreventClipping => 'Chống méo tiếng';

  @override
  String get settingsAudioPreventClippingHint =>
      'Giảm mức khi tăng âm có thể làm méo các đỉnh to nhất.';

  @override
  String get excludedFoldersTitle => 'Thư mục loại trừ';

  @override
  String get excludedFoldersHint =>
      'Các thư mục trong thư mục nhạc mà Kanaru bỏ qua. Bài hát trong đó sẽ rời khỏi thư viện. Tệp không bao giờ bị xoá.';

  @override
  String get excludedFoldersAdd => 'Loại trừ thư mục';

  @override
  String get excludedFoldersRemove => 'Bỏ loại trừ';

  @override
  String get excludedFoldersNotInLibrary =>
      'Không nằm trong thư mục nhạc nào nên không có tác dụng';

  @override
  String get excludedFoldersMissing => 'Không tìm thấy thư mục';

  @override
  String get excludedFoldersSameAsRoot =>
      'Đây là một thư mục nhạc. Hãy xoá nó khỏi danh sách thư mục ở trên.';

  @override
  String get excludedFoldersOutsideLibrary =>
      'Thư mục này không nằm trong thư mục nhạc nào.';

  @override
  String get excludedFoldersAlreadyExcluded => 'Thư mục này đã bị loại trừ.';

  @override
  String get settingsWatchFolders => 'Theo dõi thư mục nhạc';

  @override
  String get settingsWatchFoldersHint =>
      'Tự nhận file thêm, sửa, xoá khi Kanaru đang chạy, vài giây sau khi chúng ngừng thay đổi';

  @override
  String get settingsWatchFoldersLimit =>
      'Quá nhiều thư mục để theo dõi trên hệ thống này. Hãy tăng fs.inotify.max_user_watches, hoặc dùng Quét lại.';

  @override
  String get historyEmptyMessage => 'Bài hát bạn đã phát sẽ hiện ở đây.';

  @override
  String get historyToday => 'Hôm nay';

  @override
  String get historyYesterday => 'Hôm qua';

  @override
  String historyDayPlayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lượt nghe',
    );
    return '$_temp0';
  }

  @override
  String historyNthPlay(int n) {
    return '#$n';
  }

  @override
  String historyNthPlayLabel(int n) {
    return 'Lượt nghe thứ $n';
  }

  @override
  String get historyTrackMissing => 'Không có trong thư viện';

  @override
  String get historyDeletePlay => 'Xoá khỏi lịch sử';

  @override
  String get historyPlayDeleted => 'Đã xoá một lượt nghe';

  @override
  String get historyUndo => 'Hoàn tác';

  @override
  String get historyDeleteFailed =>
      'Không xoá được lượt nghe. Xem chi tiết trong nhật ký.';

  @override
  String get historyRestoreFailed =>
      'Không khôi phục được lượt nghe. Xem chi tiết trong nhật ký.';

  @override
  String get historyCalendar => 'Nhảy tới ngày';

  @override
  String get historyRecordingOff => 'Đang tắt ghi lịch sử nghe';

  @override
  String get historyUnavailable => 'Lịch sử không khả dụng';

  @override
  String get historyLoadFailed =>
      'Không đọc được lịch sử. Xem chi tiết trong nhật ký.';

  @override
  String get historyMore => 'Thêm';

  @override
  String historyOlderYear(int year) {
    return 'Xem năm $year';
  }

  @override
  String get historyTabTimeline => 'Nhật ký';

  @override
  String get historyTabTop => 'Phát nhiều nhất';

  @override
  String get historyRangeToday => 'Hôm nay';

  @override
  String get historyRange7Days => '7 ngày';

  @override
  String get historyRange30Days => '30 ngày';

  @override
  String get historyRange6Months => '6 tháng';

  @override
  String get historyRangeYear => '1 năm';

  @override
  String get historyRangeAll => 'Tất cả';

  @override
  String get historyRangeCustom => 'Tuỳ chọn';

  @override
  String get historyRangePrevious => 'Kỳ trước';

  @override
  String get historyRangeNext => 'Kỳ sau';

  @override
  String historyRangeLabel(String start, String end) {
    return '$start – $end';
  }

  @override
  String historyTopPlayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lượt',
    );
    return '$_temp0';
  }

  @override
  String historyTopCapped(int count) {
    return 'Hiện $count bài đầu';
  }

  @override
  String get historyPlayAll => 'Phát tất cả';

  @override
  String get historyCreatePlaylist => 'Tạo playlist';

  @override
  String historyTopPlaylistName(String range) {
    return 'Nghe nhiều nhất · $range';
  }

  @override
  String historyPlaylistCreated(String name) {
    return 'Đã tạo playlist $name';
  }

  @override
  String get historyTopEmpty => 'Không có lượt nghe trong khoảng này';

  @override
  String get historyShowTrackHistory => 'Lịch sử bài này';

  @override
  String get historyTrackTitle => 'Lịch sử bài hát';

  @override
  String historyTrackStats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lượt nghe',
    );
    return '$_temp0';
  }

  @override
  String historyTrackFirst(String date) {
    return 'Lần đầu $date';
  }

  @override
  String historyTrackLast(String date) {
    return 'Lần cuối $date';
  }

  @override
  String historyListened(String duration) {
    return 'đã nghe $duration';
  }

  @override
  String get historyTrackNoPlays => 'Chưa có lượt nghe nào';

  @override
  String get historyTrackNotFound => 'Không tìm thấy bài hát';

  @override
  String get historyPlay => 'Phát';

  @override
  String get favoritesRemove => 'Bỏ khỏi yêu thích';

  @override
  String get favoritesAdded => 'Đã thêm vào Yêu thích';

  @override
  String get favoritesRemoved => 'Đã bỏ khỏi Yêu thích';

  @override
  String get playlistM3uImport => 'Nhập M3U…';

  @override
  String get playlistM3uAllFiles => 'Mọi tệp';

  @override
  String get playlistM3uImporting => 'Đang nhập playlist…';

  @override
  String playlistM3uImported(int count, String name) {
    return 'Đã nhập $count bài vào $name';
  }

  @override
  String playlistM3uImportedNotInLibrary(int count) {
    return '$count bài chưa có trong thư viện';
  }

  @override
  String get playlistM3uImportReportTitle => 'Đã nhập playlist';

  @override
  String playlistM3uImportReportSummary(int added, int total) {
    return 'Đã thêm $added trên $total dòng.';
  }

  @override
  String playlistM3uImportReportNotInLibrary(int count) {
    return '$count bài chưa có trong thư viện: sẽ hiện khi thêm thư mục chứa chúng.';
  }

  @override
  String playlistM3uImportReportDuplicates(int count) {
    return 'Đã gộp $count dòng trùng.';
  }

  @override
  String playlistM3uImportReportUnresolved(int count) {
    return '$count dòng không phải tệp nhạc cục bộ hoặc không tìm thấy:';
  }

  @override
  String playlistM3uImportReportTruncated(int limit) {
    return 'Chỉ đọc $limit bài đầu tiên.';
  }

  @override
  String playlistM3uImportReportLine(int line, String text) {
    return 'Dòng $line: $text';
  }

  @override
  String playlistM3uImportReportMore(int count) {
    return 'và $count dòng khác';
  }

  @override
  String get playlistM3uImportNothingFound =>
      'Không tìm thấy tệp nhạc cục bộ nào của playlist này. Chưa nhập gì.';

  @override
  String get playlistM3uImportTooLarge => 'Tệp này quá lớn để là một playlist.';

  @override
  String get playlistM3uImportFailed =>
      'Không đọc được tệp playlist. Xem log để biết chi tiết.';

  @override
  String get playlistM3uExportAbsolute => 'Xuất M3U (đường dẫn đầy đủ)…';

  @override
  String get playlistM3uExportRelative => 'Xuất M3U (đường dẫn tương đối)…';

  @override
  String playlistM3uExported(int count, String file) {
    return 'Đã lưu $count bài vào $file';
  }

  @override
  String playlistM3uExportSkipped(int count) {
    return 'bỏ $count đường dẫn có ký tự xuống dòng';
  }

  @override
  String get playlistM3uExportFailed =>
      'Không lưu được tệp playlist. Xem log để biết chi tiết.';

  @override
  String playlistM3uOverwriteTitle(String file) {
    return 'Thay thế $file?';
  }

  @override
  String get playlistM3uOverwriteConfirm => 'Thay thế';

  @override
  String get queueSaveAsPlaylist => 'Lưu hàng đợi thành playlist';

  @override
  String queueSaveDefaultName(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Hàng đợi $dateString';
  }

  @override
  String queueSaved(int count, String name) {
    return 'Đã lưu $count bài vào $name';
  }

  @override
  String queueSavedSkipped(int count, int skipped, String name) {
    return 'Đã lưu $count bài vào $name, bỏ $skipped bài (không có trong thư viện hoặc trùng)';
  }

  @override
  String get queueSaveNothing =>
      'Không bài nào trong hàng đợi có trong thư viện';

  @override
  String get queueHistoryTitle => 'Lịch sử hàng đợi';

  @override
  String get queueHistoryEmptyTitle => 'Chưa có lịch sử hàng đợi';

  @override
  String get queueHistoryEmptyMessage =>
      'Khi bạn phát thứ khác, hàng đợi bị thay sẽ được giữ ở đây.';

  @override
  String queueHistorySavedAt(DateTime date, DateTime time) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);
    final intl.DateFormat timeDateFormat = intl.DateFormat.Hm(localeName);
    final String timeString = timeDateFormat.format(time);

    return '$dateString · $timeString';
  }

  @override
  String get queueHistoryPlay => 'Phát';

  @override
  String get queueHistoryShuffle => 'Phát ngẫu nhiên';

  @override
  String get queueHistorySaveAsPlaylist => 'Lưu thành playlist';

  @override
  String queueHistorySavedAsPlaylist(String name) {
    return 'Đã lưu thành $name';
  }

  @override
  String get queueHistoryDelete => 'Xoá';

  @override
  String get queueHistoryDeleteTitle => 'Xoá hàng đợi này?';

  @override
  String get queueHistoryDeleteMessage =>
      'Hàng đợi bị xoá khỏi lịch sử. Các bài vẫn còn trong thư viện.';

  @override
  String get queueHistoryDeleted => 'Đã xoá hàng đợi';

  @override
  String get queueHistoryNothingToPlay =>
      'Không bài nào trong đây có trong thư viện';

  @override
  String get sidebarCurrentQueue => 'Hàng đợi hiện tại';

  @override
  String get lyricsTab => 'Lời bài hát';

  @override
  String get coverCacheClearTitle => 'Xoá cache ảnh bìa?';

  @override
  String get coverCacheClearBody =>
      'Mọi ảnh bìa biến mất khỏi thư viện cho tới khi được tạo lại. Kanaru quét lại ngay và tạo lại ảnh ở nền; thư viện lớn có thể mất một lúc. Màu lấy từ ảnh bìa được giữ.';

  @override
  String coverCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã xoá $count ảnh bìa. Quét lại sẽ tạo lại chúng.',
    );
    return '$_temp0';
  }

  @override
  String get coverCacheClearFailed => 'Không xoá được cache ảnh bìa';

  @override
  String get genresUnknown => 'Không rõ thể loại';
}
