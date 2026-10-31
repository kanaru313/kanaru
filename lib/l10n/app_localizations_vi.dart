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
  String get navMostPlayed => 'Phát nhiều nhất';

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
  String get libraryShowInFolder => 'Xem trong thư mục';

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
  String get albumsFilterHint => 'Lọc album';

  @override
  String albumsFilterNoMatch(String query) {
    return 'Không có album nào khớp «$query»';
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
  String get albumsSectionEmpty => 'Không còn album nào ở đây';

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
  String albumsMinutes(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString phút';
  }

  @override
  String get albumsPlayAlbum => 'Phát album';

  @override
  String libraryHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$hoursString giờ $minutes phút';
  }

  @override
  String get artistsPlayArtist => 'Phát nghệ sĩ';

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
  String get foldersFilterAll => 'Tất cả';

  @override
  String foldersSectionFolders(int count) {
    return 'Thư mục · $count';
  }

  @override
  String foldersSectionSongs(int count) {
    return 'Bài hát · $count';
  }

  @override
  String foldersCounts(int songs, int folders) {
    return '$songs bài, $folders thư mục con';
  }

  @override
  String get foldersCreatePlaylist => 'Tạo playlist';

  @override
  String get foldersEmptyFolder => 'Thư mục này không có bài hát';

  @override
  String get foldersPlayAllBelow => 'Phát cả thư mục con';

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
  String searchNoResultsNarrowFields(String query) {
    return 'Không tìm thấy kết quả cho “$query” trong các trường đã chọn. Thử chọn thêm trường tìm.';
  }

  @override
  String get searchFieldsButton => 'Trường tìm';

  @override
  String get searchFieldsFiltered => 'Trường tìm (đã lọc)';

  @override
  String get searchPresetAll => 'Tất cả trường';

  @override
  String get searchPresetTitleOnly => 'Chỉ tiêu đề';

  @override
  String get searchFieldTitle => 'Tiêu đề';

  @override
  String get searchFieldArtist => 'Nghệ sĩ';

  @override
  String get searchFieldAlbum => 'Album';

  @override
  String get searchFieldAlbumArtist => 'Nghệ sĩ album';

  @override
  String get searchFieldGenre => 'Thể loại';

  @override
  String get searchFieldFileName => 'Tên file';

  @override
  String get searchFieldComment => 'Mô tả';

  @override
  String get searchCorrectedResultsForPrefix => 'Kết quả cho';

  @override
  String get searchHistoryTitle => 'Tìm kiếm gần đây';

  @override
  String get searchHistoryRemove => 'Xoá khỏi lịch sử';

  @override
  String get searchHistoryClearAll => 'Xoá tất cả';

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
  String get playerRepeatOff => 'Dừng lại ở bài hát cuối cùng';

  @override
  String get playerRepeatAll => 'Lặp lại tất cả trong hàng đợi';

  @override
  String get playerRepeatOne => 'Lặp lại bài hát hiện tại';

  @override
  String get playerRepeatAllShuffled =>
      'Lặp lại tất cả trong hàng đợi (xáo trộn)';

  @override
  String playerRepeatTimes(int count) {
    return 'Lặp lại thêm $count lần nữa';
  }

  @override
  String get playerRepeatFewer => 'Bớt một lần';

  @override
  String get playerRepeatMore => 'Thêm một lần';

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
  String get nowPlayingViewSplit => 'Chia đôi';

  @override
  String get nowPlayingViewCoverOnly => 'Chỉ hiện ảnh bìa';

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
  String get queueMenuStale => 'Hàng đợi đã thay đổi nên chưa thực hiện gì';

  @override
  String get queueReorder => 'Kéo để sắp xếp lại';

  @override
  String get queueShowCurrent => 'Tới bài đang phát';

  @override
  String get queueClose => 'Đóng danh sách đang phát';

  @override
  String queueSummary(String tracks, String timeLeft) {
    return '$tracks · $timeLeft';
  }

  @override
  String queueTimeLeftHours(int hours, int minutes) {
    return 'Còn $hours giờ $minutes phút';
  }

  @override
  String queueTimeLeftMinutes(int minutes) {
    return 'Còn $minutes phút';
  }

  @override
  String get queueMoreActions => 'Thêm thao tác';

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
      'Tắt: trang, bảng, tab và thanh bên đổi ngay, không chuyển động.';

  @override
  String get settingsColorFromCover => 'Màu theo ảnh bìa';

  @override
  String get settingsColorFromCoverHint =>
      'Phủ màu của ảnh bìa đang phát lên giao diện.';

  @override
  String get settingsWaveformSeekBar => 'Thanh tua dạng sóng';

  @override
  String get settingsWaveformSeekBarHint =>
      'Hiện hình dạng bài hát trên thanh tua của màn hình đang phát.';

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
  String get settingsSkipHiddenFolders => 'Bỏ qua thư mục ẩn';

  @override
  String get settingsSkipHiddenFoldersHint =>
      'Thư mục có tên bắt đầu bằng dấu chấm không vào thư viện. Có hiệu lực ở lần quét sau.';

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
      'Bài cùng tên album là một album; chọn thêm điều kiện phải trùng. Áp dụng ngay, cập nhật thư viện ở nền.';

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
      'Khoảng thời gian này, hoặc tỉ lệ này của bài, tuỳ điều kiện nào đến trước.';

  @override
  String get settingsListenAfterOr => 'hoặc';

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
      'Hiện số thứ tự của từng bài trước ảnh bìa trên trang album.';

  @override
  String get settingsLyrics => 'Lời bài hát';

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
  String historyDayDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String historySince(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'từ $dateString';
  }

  @override
  String historyPlayedAt(DateTime date, String time) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString - $time';
  }

  @override
  String get historyDayMenu => 'Tuỳ chọn ngày';

  @override
  String get historyDayCreatePlaylist => 'Tạo playlist từ ngày này';

  @override
  String get historyDayDelete => 'Xoá lượt nghe của ngày';

  @override
  String historyDayPlaylistName(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Lịch sử · $dateString';
  }

  @override
  String historyListenCount(int count) {
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
  String historyPlaysDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã xoá $count lượt nghe',
      one: 'Đã xoá một lượt nghe',
    );
    return '$_temp0';
  }

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
  String get historyRangeDialogTitle => 'Khoảng tuỳ chọn';

  @override
  String get historyRangePickStart => 'Chọn ngày bắt đầu';

  @override
  String get historyRangePickEnd => 'Chọn ngày kết thúc';

  @override
  String historyRangeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ngày',
    );
    return '$_temp0';
  }

  @override
  String get historyRangeDayHasListens => 'Có lượt nghe';

  @override
  String get historyRangeStartPlaceholder => 'Ngày bắt đầu';

  @override
  String get historyRangeEndPlaceholder => 'Ngày kết thúc';

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
  String get queueHistoryTitle => 'Các hàng đợi';

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
  String get lyricsNone => 'Bài này chưa có lời';

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

  @override
  String get separatorsArtistsTitle => 'Tách nghệ sĩ';

  @override
  String get separatorsGenresTitle => 'Tách thể loại';

  @override
  String get separatorsArtistsHint => 'Áp dụng ngay, cập nhật thư viện ở nền.';

  @override
  String get separatorsGenresHint => 'Áp dụng ngay, không cần quét lại.';

  @override
  String separatorsSummary(int separators, int keepWhole) {
    return '$separators dấu phân cách · $keepWhole tên giữ nguyên';
  }

  @override
  String get separatorsEditButton => 'Chỉnh sửa';

  @override
  String separatorsTabSeparators(int count) {
    return 'Dấu phân cách ($count)';
  }

  @override
  String separatorsTabKeepWhole(int count) {
    return 'Không tách ($count)';
  }

  @override
  String get separatorsAddSeparatorLabel => 'Dấu phân cách mới';

  @override
  String get separatorsAddKeepLabel => 'Tên giữ nguyên';

  @override
  String get separatorsSeparatorHelp =>
      'Không cần thêm khoảng trắng hai đầu. Chữ như feat. chỉ tách khi có khoảng trắng hai bên.';

  @override
  String get separatorsKeepHelpArtist =>
      'Gõ tên như trong tag, không phân biệt hoa thường. Ví dụ AC/DC vẫn là một nghệ sĩ.';

  @override
  String get separatorsKeepHelpGenre =>
      'Gõ tên như trong tag, không phân biệt hoa thường. Ví dụ Funk/Soul vẫn là một thể loại.';

  @override
  String get separatorsAdd => 'Thêm';

  @override
  String get separatorsErrorEmpty => 'Nhập nội dung cần thêm';

  @override
  String get separatorsErrorDuplicate => 'Đã có trong danh sách';

  @override
  String separatorsErrorTooLong(int max) {
    return 'Tối đa $max ký tự';
  }

  @override
  String separatorsErrorFull(int max) {
    return 'Danh sách chứa tối đa $max mục';
  }

  @override
  String separatorsRemove(String entry) {
    return 'Xoá $entry';
  }

  @override
  String get separatorsEmptyList => 'Chưa có mục nào';

  @override
  String get separatorsEmptySeparators =>
      'Chưa có mục nào, nên không tách gì cả';

  @override
  String separatorsPage(int page, int total) {
    return 'Trang $page / $total';
  }

  @override
  String get separatorsReset => 'Khôi phục mặc định';

  @override
  String get separatorsResetConfirmTitle => 'Khôi phục mặc định?';

  @override
  String get separatorsResetConfirmBody => 'Cả hai danh sách trở về mặc định.';

  @override
  String get separatorsResetConfirm => 'Khôi phục';

  @override
  String get separatorsClose => 'Đóng';

  @override
  String get scanStatsTracksTitle => 'Bài trong thư viện';

  @override
  String scanStatsTracksOfFiles(int tracks, int files) {
    final intl.NumberFormat tracksNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String tracksString = tracksNumberFormat.format(tracks);
    final intl.NumberFormat filesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String filesString = filesNumberFormat.format(files);

    return '$tracksString trên $filesString file nhạc';
  }

  @override
  String get scanStatsNotScanned => 'Chưa quét trong phiên này';

  @override
  String get scanStatsLeftOutTitle => 'Bị loại do luật quét';

  @override
  String scanStatsNomedia(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'File trong thư mục có .nomedia: $countString';
  }

  @override
  String scanStatsExcluded(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'File trong thư mục loại trừ: $countString';
  }

  @override
  String scanStatsTooSmall(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'File dưới cỡ tối thiểu: $countString';
  }

  @override
  String scanStatsTooShort(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'File ngắn hơn thời lượng tối thiểu: $countString';
  }

  @override
  String get scanStatsTagErrorsTitle => 'Lỗi tag';

  @override
  String scanStatsTagErrors(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString bài không đọc được tag (vẫn lưu)',
      zero: 'Không có bài lỗi tag',
    );
    return '$_temp0';
  }

  @override
  String get scanStatsCoversTitle => 'Ảnh bìa';

  @override
  String scanStatsCovers(int images, int tracks) {
    final intl.NumberFormat imagesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String imagesString = imagesNumberFormat.format(images);
    final intl.NumberFormat tracksNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String tracksString = tracksNumberFormat.format(tracks);

    return '$imagesString ảnh đã tạo cho $tracksString bài có ảnh';
  }

  @override
  String scanStatsSongs(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString bài';
  }

  @override
  String scanStatsUnfinishedRoots(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString thư mục chưa quét xong';
  }

  @override
  String get scanStatsCoversHint =>
      'Kanaru tự tạo ảnh thu nhỏ từ ảnh trong file hoặc thư mục. Ảnh trùng chỉ lưu một lần (theo hash).';

  @override
  String get sleepTimer => 'Hẹn giờ ngủ';

  @override
  String sleepTimerActive(String state) {
    return 'Hẹn giờ ngủ: $state';
  }

  @override
  String sleepTimerMinutes(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString phút';
  }

  @override
  String get sleepTimerCustom => 'Tuỳ chỉnh…';

  @override
  String get sleepTimerEndOfTrack => 'Hết bài';

  @override
  String get sleepTimerEndOfAlbum => 'Hết album';

  @override
  String get sleepTimerEndOfQueue => 'Hết hàng đợi';

  @override
  String sleepTimerLeft(String time) {
    return 'Còn $time';
  }

  @override
  String sleepTimerLeftPaused(String time) {
    return 'Còn $time (tạm dừng đếm)';
  }

  @override
  String get sleepTimerAdd => 'Thêm 5 phút';

  @override
  String get sleepTimerSubtract => 'Bớt 5 phút';

  @override
  String get sleepTimerPauseCounting => 'Tạm dừng đếm';

  @override
  String get sleepTimerResumeCounting => 'Tiếp tục đếm';

  @override
  String get sleepTimerCancel => 'Huỷ hẹn giờ';

  @override
  String get sleepTimerCustomTitle => 'Hẹn giờ ngủ tuỳ chỉnh';

  @override
  String get sleepTimerCustomLabel => 'Số phút';

  @override
  String sleepTimerCustomInvalid(int min, int max) {
    return 'Nhập số nguyên từ $min đến $max';
  }

  @override
  String get sleepTimerStart => 'Bắt đầu';

  @override
  String get sleepTimerLabelTrack => 'Bài';

  @override
  String get sleepTimerLabelAlbum => 'Album';

  @override
  String get sleepTimerLabelQueue => 'Hàng đợi';

  @override
  String get navLanguages => 'Ngôn ngữ';

  @override
  String get languagesComingSoonTitle => 'Ngôn ngữ sắp có';

  @override
  String get languagesComingSoonMessage =>
      'Chưa thể duyệt bài hát theo ngôn ngữ.';

  @override
  String get languageNameEng => 'Tiếng Anh';

  @override
  String get languageNameVie => 'Tiếng Việt';

  @override
  String get languageNameJpn => 'Tiếng Nhật';

  @override
  String get languageNameKor => 'Tiếng Hàn';

  @override
  String get languageNameZho => 'Tiếng Trung';

  @override
  String get languageNameFra => 'Tiếng Pháp';

  @override
  String get languageNameDeu => 'Tiếng Đức';

  @override
  String get languageNameSpa => 'Tiếng Tây Ban Nha';

  @override
  String get languageNameIta => 'Tiếng Ý';

  @override
  String get languageNameRus => 'Tiếng Nga';

  @override
  String get languageNamePor => 'Tiếng Bồ Đào Nha';

  @override
  String get languageNameTha => 'Tiếng Thái';

  @override
  String get languageNameInd => 'Tiếng Indonesia';

  @override
  String get languageNameHin => 'Tiếng Hindi';

  @override
  String get languageNameAra => 'Tiếng Ả Rập';

  @override
  String get languageNameNld => 'Tiếng Hà Lan';

  @override
  String get languageNameSwe => 'Tiếng Thụy Điển';

  @override
  String get languageNamePol => 'Tiếng Ba Lan';

  @override
  String get languageNameTur => 'Tiếng Thổ Nhĩ Kỳ';

  @override
  String get languageNameUkr => 'Tiếng Ukraina';

  @override
  String get languageNameCes => 'Tiếng Séc';

  @override
  String get languageNameEll => 'Tiếng Hy Lạp';

  @override
  String get languageNameFas => 'Tiếng Ba Tư';

  @override
  String get languageNameRon => 'Tiếng Romania';

  @override
  String get languageNameMsa => 'Tiếng Mã Lai';

  @override
  String get languageNameHeb => 'Tiếng Do Thái';

  @override
  String get languageNameFin => 'Tiếng Phần Lan';

  @override
  String get languageNameDan => 'Tiếng Đan Mạch';

  @override
  String get languageNameNor => 'Tiếng Na Uy';

  @override
  String get languageNameHun => 'Tiếng Hungary';

  @override
  String get languageNameCym => 'Tiếng Wales';

  @override
  String get languageNameSlk => 'Tiếng Slovak';

  @override
  String get languageNameSqi => 'Tiếng Albania';

  @override
  String get languageNameHye => 'Tiếng Armenia';

  @override
  String get languageNameEus => 'Tiếng Basque';

  @override
  String get languageNameMya => 'Tiếng Miến Điện';

  @override
  String get languageNameKat => 'Tiếng Georgia';

  @override
  String get languageNameIsl => 'Tiếng Iceland';

  @override
  String get languageNameMkd => 'Tiếng Bắc Macedonia';

  @override
  String get languageNameMri => 'Tiếng Maori';

  @override
  String get languageNameBod => 'Tiếng Tây Tạng';

  @override
  String get languageNameZxx => 'Không lời';

  @override
  String get languageNameMul => 'Nhiều ngôn ngữ';

  @override
  String get languagesNoRootsMessage => 'Thêm thư mục nhạc ở mục Bài hát.';

  @override
  String get languagesEmptyTitle => 'Chưa có ngôn ngữ nào';

  @override
  String get languagesEmptyMessage =>
      'Bài hát có tag ngôn ngữ (TLAN trong MP3, LANGUAGE trong FLAC và Ogg) sẽ hiện ở đây theo ngôn ngữ. Quét lại thư mục để đọc tag.';

  @override
  String get languagesAlbums => 'Album';

  @override
  String get languagesSongs => 'Bài hát';

  @override
  String get languagesNotFound => 'Không tìm thấy ngôn ngữ';

  @override
  String get languagesNotFoundMessage =>
      'Có thể bài hát đã bị xoá hoặc đổi tag.';

  @override
  String get albumVariousArtists => 'Nhiều nghệ sĩ';

  @override
  String get inPageSearchHint => 'Lọc bài hát';

  @override
  String get inPageSearchOpen => 'Lọc trong trang';

  @override
  String get inPageSearchClear => 'Xoá bộ lọc';

  @override
  String inPageSearchNoMatch(String query) {
    return 'Không có bài nào khớp «$query»';
  }

  @override
  String inPageSearchTooMany(int count) {
    return 'Hiện $count bài đầu, gõ thêm chữ để thu hẹp.';
  }

  @override
  String get homeRecentlyPlayedTitle => 'Lượt nghe gần đây';

  @override
  String get homeRecentlyAddedTitle => 'Gần đây nhất';

  @override
  String get homeMemoriesTitle => 'Kí ức đã mất';

  @override
  String get homeRecentAlbumsTitle => 'Album gần đây';

  @override
  String get homeRecentArtistsTitle => 'Nghệ sĩ gần đây';

  @override
  String get homeMemoriesEmpty =>
      'Khoảng thời gian này không có bất kỳ bản nhạc nào';

  @override
  String get homeAddedWindowAll => 'Tất cả';

  @override
  String get homeSeeAll => 'Xem tất cả';

  @override
  String get homeScrollBack => 'Cuộn lùi';

  @override
  String get homeScrollForward => 'Cuộn tới';

  @override
  String homeAddedWindowDays(int count) {
    return '$count ngày';
  }

  @override
  String get homeRecentlyAddedEmpty =>
      'Không có bài nào được thêm trong khoảng này';

  @override
  String get homeRecentAlbumsEmpty => 'Chưa nghe album nào';

  @override
  String get homeRecentArtistsEmpty => 'Chưa nghe nghệ sĩ nào';

  @override
  String get homeLoadFailed => 'Không đọc được danh sách';

  @override
  String get homeRetry => 'Thử lại';

  @override
  String get lyricsTranslationButton => 'Dịch lời bài hát';

  @override
  String get lyricsTranslationButtonLoading => 'Dịch lời bài hát: đang dịch';

  @override
  String get lyricsTranslationButtonFailed => 'Dịch lời bài hát: lỗi';

  @override
  String get lyricsTranslationShow => 'Hiện bản dịch';

  @override
  String lyricsTranslationTarget(String language) {
    return 'Dịch sang: $language';
  }

  @override
  String lyricsTranslationTargetDefault(String language) {
    return 'Mặc định ($language)';
  }

  @override
  String get lyricsTranslationDisplayHeader => 'Kiểu hiển thị';

  @override
  String get lyricsTranslationDisplayUnder => 'Dưới mỗi dòng';

  @override
  String get lyricsTranslationDisplayReplace => 'Thay dòng gốc';

  @override
  String get lyricsTranslationServiceHeader => 'Dịch vụ';

  @override
  String get lyricsTranslationSaved => 'Đã lưu bản dịch';

  @override
  String lyricsTranslationSavedFrom(String service) {
    return 'Đã lưu từ $service';
  }

  @override
  String get lyricsTranslationRetranslate => 'Dịch lại';

  @override
  String lyricsTranslationRetranslateWith(String service) {
    return 'Dịch lại bằng $service';
  }

  @override
  String lyricsTranslationSameLanguage(String language) {
    return 'Lời bài hát đã là $language';
  }

  @override
  String get lyricsTranslationLoading => 'Đang dịch…';

  @override
  String get lyricsTranslationRetry => 'Thử lại';

  @override
  String get lyricsTranslationFailNetwork =>
      'Không kết nối được tới dịch vụ. Kiểm tra mạng của bạn.';

  @override
  String get lyricsTranslationFailNoKey =>
      'Hãy thêm khóa API DeepL trong Cài đặt.';

  @override
  String get lyricsTranslationFailBadKey =>
      'DeepL từ chối khóa API. Hãy kiểm tra lại trong Cài đặt.';

  @override
  String get lyricsTranslationFailQuota =>
      'Đã hết hạn mức ký tự của tháng này.';

  @override
  String get lyricsTranslationFailRateLimited =>
      'Quá nhiều yêu cầu. Hãy thử lại sau ít phút.';

  @override
  String get lyricsTranslationFailBlocked =>
      'Dịch vụ đã chặn yêu cầu. Hãy thử lại sau hoặc dùng dịch vụ còn lại.';

  @override
  String get lyricsTranslationFailUnsupportedLanguage =>
      'Dịch vụ này không dịch được sang ngôn ngữ này.';

  @override
  String get lyricsTranslationFailTooLong => 'Lời bài hát này quá dài để dịch.';

  @override
  String get lyricsTranslationFailServer => 'Dịch vụ gặp lỗi. Hãy thử lại sau.';

  @override
  String get lyricsTranslationFailInvalidResponse =>
      'Dịch vụ trả về dữ liệu không đọc được.';

  @override
  String get lyricsTranslationFailEmptyResult =>
      'Dịch vụ không trả về bản dịch nào.';

  @override
  String get lyricsTranslationFailKeyStoreLocked =>
      'Kho khóa đang bị khóa. Hãy mở khóa để dùng khóa DeepL.';

  @override
  String get lyricsTranslationFailKeyStoreUnavailable =>
      'Không dùng được kho khóa nên không đọc được khóa DeepL.';

  @override
  String lyricsTranslationAttribution(String service, String language) {
    return 'Dịch bởi $service · $language';
  }

  @override
  String lyricsTranslationButtonLabel(String service, String language) {
    return '$service · $language';
  }

  @override
  String lyricsTranslationUseService(String service) {
    return 'Dùng $service';
  }

  @override
  String get lyricsTranslationBannerNoKey =>
      'Hãy thêm khóa DeepL trong Cài đặt › Lời bài hát.';

  @override
  String get lyricsTranslationBannerBadKey =>
      'DeepL từ chối khóa. Hãy kiểm tra khóa trong Cài đặt › Lời bài hát.';

  @override
  String translationNoticeTitle(String service) {
    return 'Lời bài hát sẽ được gửi tới $service';
  }

  @override
  String translationNoticeBody(String service) {
    return 'Nội dung lời của bài hát này sẽ được gửi tới $service để dịch. Không gửi thông tin nào khác.';
  }

  @override
  String get translationNoticeGoogleUnofficial =>
      'Google được dùng qua một địa chỉ web không chính thức nên có thể ngừng hoạt động bất cứ lúc nào.';

  @override
  String get translationNoticeContinue => 'Tiếp tục';

  @override
  String get languageNameZhHans => 'Tiếng Trung (giản thể)';

  @override
  String get languageNameZhHant => 'Tiếng Trung (phồn thể)';

  @override
  String get settingsTranslationService => 'Dịch vụ dịch lời';

  @override
  String get settingsTranslationServiceGoogleHint =>
      'Dịch vụ miễn phí, không chính thức; có thể ngừng hoạt động. Lời bài hát được gửi tới dịch vụ này khi bật dịch.';

  @override
  String get settingsTranslationServiceDeeplHint =>
      'Cần khóa API DeepL của bạn. Lời bài hát được gửi tới DeepL khi bật dịch.';

  @override
  String get settingsTranslationTarget => 'Ngôn ngữ dịch mặc định';

  @override
  String get settingsTranslationTargetHint =>
      'Dùng cho những bài chưa chọn ngôn ngữ riêng.';

  @override
  String settingsTranslationTargetFollow(String language) {
    return 'Theo ngôn ngữ ứng dụng ($language)';
  }

  @override
  String get deeplKeyTitle => 'Khóa API DeepL';

  @override
  String get deeplKeyNone => 'Chưa lưu khóa';

  @override
  String get deeplKeyAdd => 'Thêm khóa';

  @override
  String get deeplKeyEdit => 'Sửa';

  @override
  String get deeplKeyClear => 'Xóa';

  @override
  String get deeplKeyPlanFree => 'Miễn phí';

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

    return 'Đã dùng $usedString / $limitString ký tự';
  }

  @override
  String deeplKeyUsageNoLimit(int used) {
    final intl.NumberFormat usedNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String usedString = usedNumberFormat.format(used);

    return 'Đã dùng $usedString ký tự';
  }

  @override
  String get deeplKeyUsageHint =>
      'Mức dùng được lấy từ DeepL khi bạn bấm làm mới.';

  @override
  String get deeplKeyRefresh => 'Làm mới mức dùng';

  @override
  String get deeplKeyClearTitle => 'Xóa khóa DeepL?';

  @override
  String get deeplKeyClearBody =>
      'Khóa sẽ bị xóa khỏi máy này. Bạn không dịch được lời bằng DeepL cho tới khi thêm khóa mới.';

  @override
  String get deeplKeyClearFailed => 'Không xóa được khóa';

  @override
  String get deeplKeyDialogTitleAdd => 'Thêm khóa API DeepL';

  @override
  String get deeplKeyDialogTitleEdit => 'Đổi khóa API DeepL';

  @override
  String get deeplKeyDialogHint =>
      'Dán khóa từ tài khoản DeepL của bạn. DeepL sẽ kiểm tra khóa trước khi lưu.';

  @override
  String get deeplKeyFieldLabel => 'Khóa API';

  @override
  String get deeplKeySave => 'Lưu';

  @override
  String get deeplKeyBadKey =>
      'DeepL không chấp nhận khóa này. Hãy kiểm tra rồi thử lại.';

  @override
  String get deeplKeySaveFailed => 'Không lưu được khóa.';

  @override
  String get deeplKeyReadFailed => 'Không đọc được khóa.';

  @override
  String get deeplKeyKeyringLocked =>
      'Kho khóa đang bị khóa; hãy mở khóa rồi thử lại';

  @override
  String get deeplKeyKeyringNoDefault =>
      'Chưa có kho khóa mặc định; hãy tạo một kho (ví dụ trong Seahorse hoặc KWallet) rồi thử lại';

  @override
  String get deeplKeyKeyringTimeout => 'Kho khóa không phản hồi';

  @override
  String get deeplKeyKeyringUnavailable => 'Hiện không dùng được kho khóa';

  @override
  String get deeplKeyFileFailed => 'Không đọc hoặc ghi được tệp khóa';

  @override
  String deeplKeyFallbackFile(String path) {
    return 'Không tìm thấy kho khóa của hệ thống; khóa được lưu trong một tệp chỉ bạn đọc được ($path). Đừng chia sẻ hay đồng bộ tệp này.';
  }

  @override
  String get deeplKeyFallbackMemory =>
      'Không tìm thấy kho khóa của hệ thống; khóa chỉ được giữ tới khi đóng Kanaru.';

  @override
  String get deeplKeyFallbackFixed =>
      'Tệp khóa từng cho người khác đọc; quyền truy cập đã được sửa. Nên cân nhắc đổi khóa.';

  @override
  String get settingsTranslationCache => 'Bản dịch đã lưu';

  @override
  String translationCacheSummary(int count, String size) {
    return '$count bài · $size';
  }

  @override
  String get translationCacheEmpty => 'Chưa có bản dịch nào được lưu';

  @override
  String get translationCacheClearTitle => 'Xóa các bản dịch đã lưu?';

  @override
  String get translationCacheClearBody =>
      'Các bản dịch đã lưu trên máy này sẽ bị xóa. Cài đặt dịch được giữ nguyên; lời sẽ được dịch lại khi cần.';

  @override
  String translationCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã xóa $count bản dịch',
      zero: 'Không có bản dịch nào để xóa',
    );
    return '$_temp0';
  }

  @override
  String get translationCacheClearFailed =>
      'Không xóa được các bản dịch đã lưu';

  @override
  String settingsUnitBytes(int count) {
    return '$count B';
  }

  @override
  String get settingsClear => 'Xóa';

  @override
  String get onlineLyricsNoticeAutoTitle => 'Tự động tìm lời online?';

  @override
  String get onlineLyricsNoticeManualTitle => 'Tìm lời bài hát online?';

  @override
  String get onlineLyricsNoticeSourcesBody =>
      'Kanaru sẽ gửi tên bài, nghệ sĩ, album và độ dài tới các nguồn lời đang bật. Không gửi tên file, đường dẫn hay thông tin máy.';

  @override
  String get onlineLyricsNoticeAutoHint =>
      'Tắt lại được trong Cài đặt › Lời bài hát.';

  @override
  String get onlineLyricsNoticeTurnOn => 'Bật';

  @override
  String get onlineLyricsNoticeSearch => 'Tìm';

  @override
  String get lyricsFindOnline => 'Tìm lời online…';

  @override
  String get lyricsPickerTitle => 'Chọn lời bài hát';

  @override
  String lyricsPickerSong(String title, String artist, String duration) {
    return 'Bài: $title · $artist · $duration';
  }

  @override
  String get lyricsPickerSearch => 'Tìm';

  @override
  String get lyricsPickerQueryHint => 'Nghệ sĩ và tên bài';

  @override
  String get lyricsPickerSynced => 'Đồng bộ';

  @override
  String get lyricsPickerPlain => 'Lời thường';

  @override
  String get lyricsPickerInstrumental => 'Nhạc không lời';

  @override
  String get lyricsPickerGoodMatch => 'Khớp tốt';

  @override
  String get lyricsPickerRejected => 'Đã từ chối';

  @override
  String lyricsPickerDelta(int seconds) {
    return '±$seconds giây';
  }

  @override
  String get lyricsPickerBlankHint => 'Nhập ca sĩ và tên bài rồi bấm Tìm';

  @override
  String get lyricsPickerEmpty => 'Không tìm thấy lời. Thử từ khóa khác.';

  @override
  String get lyricsPickerRetry => 'Thử lại';

  @override
  String lyricsPickerFooter(String hosts) {
    return 'Kết quả từ $hosts · lời bạn chọn được ghim vào bài này';
  }

  @override
  String get lyricsPickerUse => 'Dùng lời này';

  @override
  String get lyricsPickerNoPreview => 'Chọn một kết quả để xem trước lời';

  @override
  String get lyricsPickerNoBody => 'Không xem trước hoặc dùng được lời này';

  @override
  String get lyricsPickerInstrumentalPreview => 'Bài này không có lời';

  @override
  String get lyricsPinned => 'Đã chọn lời cho bài này';

  @override
  String get lyricsPickFailed => 'Không ghim được lời này';

  @override
  String lyricsPickerNotConsented(String provider) {
    return 'Bạn chưa cho phép tìm lời trên $provider.';
  }

  @override
  String lyricsSearching(String provider) {
    return 'Đang tìm trên $provider…';
  }

  @override
  String get lyricsFindAutomatically => 'Tự động tìm lời';

  @override
  String lyricsNotFound(String provider) {
    return 'Không có lời trên $provider';
  }

  @override
  String get lyricsSearchManually => 'Tìm thủ công…';

  @override
  String lyricsOnlineError(String provider) {
    return 'Không kết nối được $provider';
  }

  @override
  String lyricsOnlineBusy(String provider) {
    return '$provider đang bận, thử lại sau giây lát.';
  }

  @override
  String get lyricsRetry => 'Thử lại';

  @override
  String get lyricsChoose => 'Chọn lời…';

  @override
  String get lyricsInstrumental => 'Nhạc không lời';

  @override
  String get lyricsMenuNotThese => 'Không phải lời này';

  @override
  String get settingsAutoOnlineLyrics => 'Tự động tìm lời online';

  @override
  String get settingsAutoOnlineLyricsHint =>
      'Khi màn hình Đang phát mở, cho các bài chưa có lời trên máy này. Mục \"Tìm lời online…\" trong menu bài luôn dùng được.';

  @override
  String get settingsSavedLyrics => 'Lời đã lưu';

  @override
  String settingsSavedLyricsSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bài có lời',
    );
    return '$_temp0';
  }

  @override
  String settingsSavedLyricsNotFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bài không thấy',
    );
    return '$_temp0';
  }

  @override
  String settingsSavedLyricsChoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lựa chọn nguồn',
    );
    return '$_temp0';
  }

  @override
  String settingsSavedLyricsRejects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bản đã từ chối',
    );
    return '$_temp0';
  }

  @override
  String get settingsLyricsConsent => 'Quyền tìm lời online';

  @override
  String get settingsLyricsConsentNone => 'Chưa cho phép';

  @override
  String get settingsLyricsConsentManual => 'Đã cho phép tìm thủ công';

  @override
  String get settingsLyricsConsentAuto => 'Đã cho phép tìm thủ công và tự động';

  @override
  String get settingsLyricsConsentWithdraw => 'Rút lại đồng ý';

  @override
  String get settingsLyricsConsentWithdrawTitle => 'Rút lại đồng ý?';

  @override
  String get settingsLyricsConsentWithdrawBody =>
      'Không còn gửi gì tới các nguồn lời online, và tìm tự động sẽ tắt. Lời đã lưu vẫn còn, và app sẽ hỏi lại trước lần tìm tiếp theo.';

  @override
  String get settingsSavedLyricsNone => 'Chưa lưu gì';

  @override
  String get settingsSavedLyricsClear => 'Xóa';

  @override
  String get settingsSavedLyricsClearTitle => 'Xóa lời đã lưu?';

  @override
  String get settingsSavedLyricsClearBody =>
      'Sẽ xóa: lời đã lưu, lựa chọn nguồn của từng bài và các bản đã từ chối. File .lrc cạnh bài không bị xóa.';

  @override
  String get settingsSavedLyricsCleared => 'Đã xóa lời đã lưu';

  @override
  String get settingsSavedLyricsClearFailed => 'Không xóa được lời đã lưu';

  @override
  String get lyricsSaveTitle => 'Lưu lời';

  @override
  String get lyricsSaveOptionLrc => 'File .lrc';

  @override
  String get lyricsSaveOptionTags => 'Trong tag nhạc';

  @override
  String get lyricsSaveOptionTagsSoon => 'Sắp có';

  @override
  String get lyricsSaveConfirm => 'Lưu';

  @override
  String lyricsReplaceTitle(String files, String title) {
    return 'Thay file $files của bài $title?';
  }

  @override
  String get lyricsReplaceBody => 'File cũ được chuyển vào thùng rác.';

  @override
  String get lyricsReplaceAction => 'Thay';

  @override
  String get lyricsSaveWritten => 'Đã lưu lời thành file .lrc';

  @override
  String get lyricsSaveIdentical => 'File .lrc đã có đúng lời này';

  @override
  String get lyricsSaveKeptTag =>
      'Bài vẫn dùng bản đã chọn vì đang ưu tiên lời trong tag';

  @override
  String get lyricsSaveKeptOtherFile =>
      'Bài vẫn dùng bản đã chọn vì Kanaru đọc một file lời khác của bài';

  @override
  String get lyricsSaveOutsideLibrary =>
      'Không lưu được: bài nằm ngoài thư mục thư viện';

  @override
  String get lyricsSaveFailed =>
      'Không lưu được file .lrc (thư mục chỉ đọc, hết chỗ hoặc không có quyền)';

  @override
  String get lyricsSaveTrashFailed =>
      'Không chuyển được file cũ vào thùng rác nên chưa thay gì';

  @override
  String get lyricsSaveTrashedNotWritten =>
      'Đã chuyển file cũ vào thùng rác nhưng không ghi được file mới; khôi phục trong thùng rác nếu cần';

  @override
  String get lyricsSaveNothing => 'Không có lời để lưu';

  @override
  String get lyricsSaveTrashTimedOut =>
      'Thùng rác không trả lời kịp; file cũ có thể đã nằm trong thùng rác, chưa ghi file mới';

  @override
  String get lyricsSaveReplaceRaced =>
      'Vừa có một file lời khác xuất hiện nên chưa thay gì';

  @override
  String lyricsReplaceFilesJoin(String first, String second) {
    return '$first và $second';
  }

  @override
  String get lyricsSourceOff => 'Đã tắt lời';

  @override
  String get lyricsSourceSearching => 'Đang tìm…';

  @override
  String get lyricsSourcePaused => 'Tạm dừng tìm';

  @override
  String get lyricsSourceNone => 'Không có lời';

  @override
  String get lyricsSourceFile => 'File .lrc';

  @override
  String get lyricsSourceTag => 'Lời trong tag';

  @override
  String get lyricsSourceSynced => 'Đồng bộ';

  @override
  String get lyricsSourcePlain => 'Lời thường';

  @override
  String lyricsSourceOnline(String provider, String kind) {
    return '$provider · $kind';
  }

  @override
  String lyricsSourceAuto(String label) {
    return 'Tự động · $label';
  }

  @override
  String get lyricsSourceMenuHeader => 'Nguồn lời cho bài này';

  @override
  String lyricsSourceMenuFrom(String source) {
    return 'Lời từ $source';
  }

  @override
  String get lyricsSourceAutoItem => 'Tự động';

  @override
  String lyricsSourceAutoNow(String label) {
    return 'Đang dùng: $label';
  }

  @override
  String get lyricsSourceAutoHintLocalOnly => 'Chỉ file hoặc tag';

  @override
  String get lyricsSourceAutoHint =>
      'File hoặc tag trước, sau đó các nguồn trực tuyến';

  @override
  String lyricsSourceForgetPick(String text) {
    return '$text · bỏ bản đã chọn';
  }

  @override
  String get lyricsSourceLocalItem => 'Lời trong file';

  @override
  String get lyricsSourceLocalTag => 'Trong tag';

  @override
  String get lyricsSourceLocalMissing => 'Không tìm thấy lời trong file';

  @override
  String lyricsSourceOnlineItem(String provider) {
    return '$provider · bản đã chọn';
  }

  @override
  String lyricsSourceOnlineSubtitle(String kind, String length) {
    return '$kind · $length';
  }

  @override
  String get lyricsSourceKeep => 'Giữ bản này';

  @override
  String get lyricsSourceSave => 'Lưu lời…';

  @override
  String get lyricsSourceTurnOff => 'Tắt lời cho bài này';

  @override
  String get lyricsOffTitle => 'Đã tắt lời cho bài này';

  @override
  String get lyricsOffTurnOn => 'Bật lại';

  @override
  String lyricsPausedTitle(String provider, DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return '$provider đang bận, Kanaru tự tìm lại lúc $timeString';
  }

  @override
  String lyricsOnlineUnreadable(String provider) {
    return '$provider trả lời mà Kanaru không đọc được';
  }

  @override
  String get lyricsAutoNeedsTags =>
      'Bài này thiếu tên bài, ca sĩ hoặc thời lượng nên không tự tìm được; dùng Tìm lời online…';

  @override
  String get lyricsSourcesTitle => 'Nguồn lời';

  @override
  String lyricsSourcesRowSubtitle(String names, int count) {
    return '$names · $count đang bật';
  }

  @override
  String get lyricsSourcesRowNoneOn => 'Mọi nguồn đang tắt';

  @override
  String get lyricsSourcesInfo =>
      'Kanaru thử lần lượt các nguồn đang bật, từ trên xuống, khi tự động tìm lời. Chọn lời sẽ tìm ở mọi nguồn đang bật. Bạn có thể kéo tay cầm để đổi thứ tự.';

  @override
  String get lyricsSourcesStore => 'Kho plugin';

  @override
  String get lyricsSourcesEmptyHint =>
      'Chưa cài plugin nào. Bạn có thể thêm plugin từ Kho plugin.';

  @override
  String get lyricsSourceBuiltIn => 'Có sẵn';

  @override
  String lyricsSourceBuiltInHosts(String hosts) {
    return 'Có sẵn · $hosts';
  }

  @override
  String get lyricsSourceDragHandle =>
      'Kéo để đổi thứ tự (bàn phím: Alt + mũi tên lên hoặc xuống)';

  @override
  String get lyricsSourceUnknownAuthor => 'Không rõ tác giả';

  @override
  String lyricsSourceAuthor(String author) {
    return '$author (tự khai báo)';
  }

  @override
  String lyricsSourceFromFile(String name) {
    return 'File: $name';
  }

  @override
  String lyricsSourceFromRepo(String name) {
    return 'Repo: $name';
  }

  @override
  String get lyricsSourcesMenuLogFolder => 'Mở thư mục log';

  @override
  String get lyricsSourcesMenuGuide => 'Hướng dẫn viết plugin';

  @override
  String get pluginUninstall => 'Gỡ plugin';

  @override
  String get pluginGone => 'Plugin này không còn được cài.';

  @override
  String pluginUpdateAvailable(int version) {
    return 'Có bản mới v$version';
  }

  @override
  String get pluginDetailsTitle => 'Chi tiết plugin';

  @override
  String get pluginUpdateRefreshList => 'Làm mới danh sách';

  @override
  String lyricsStoreUpdateVersions(int installed, int available) {
    return 'v$installed → v$available';
  }

  @override
  String get pluginUpdateAction => 'Cập nhật';

  @override
  String pluginUpdateFailed(String name) {
    return 'Không cập nhật được $name';
  }

  @override
  String get pluginInfoTitle => 'Chi tiết';

  @override
  String get pluginInfoSource => 'Cài từ';

  @override
  String get pluginInfoHosts => 'Chỉ được kết nối tới';

  @override
  String get pluginInfoInstalled => 'Cài lúc';

  @override
  String pluginInfoInstalledUpdated(String installed, String updated) {
    return '$installed · cập nhật $updated';
  }

  @override
  String get pluginInfoDescription => 'Mô tả';

  @override
  String get pluginConfigTitle => 'Cài đặt của plugin';

  @override
  String get pluginSecretNote =>
      'Giá trị bí mật: lưu trong kho khóa của hệ thống, không nằm trong cài đặt hay log.';

  @override
  String get pluginSecretSaved => 'Đã lưu trong kho khóa';

  @override
  String get pluginSecretFallbackNote =>
      'Không tìm thấy kho khóa của hệ thống. Giá trị bí mật được lưu trong một file chỉ bạn đọc được, hoặc chỉ được giữ tới khi đóng Kanaru. Đừng chia sẻ hay đồng bộ file này.';

  @override
  String get pluginSecretShow => 'Hiện giá trị';

  @override
  String get pluginSecretHide => 'Ẩn giá trị';

  @override
  String get pluginSecretClear => 'Xóa giá trị đã lưu';

  @override
  String get pluginConfigNumberInvalid => 'Nhập một số';

  @override
  String get pluginConfigInvalidValue => 'Cài đặt này không nhận giá trị đó.';

  @override
  String get pluginConfigTooLarge =>
      'Cài đặt của plugin quá lớn, không lưu được.';

  @override
  String get pluginConfigUnknownKey =>
      'Cài đặt này không còn nữa. Plugin có thể đã bị gỡ hoặc đổi.';

  @override
  String get pluginConfigSecretStoreFailed =>
      'Không truy cập được kho khóa của hệ thống. Hãy mở khóa kho khóa hoặc khởi động lại Kanaru rồi thử lại.';

  @override
  String get pluginDataTitle => 'Dữ liệu';

  @override
  String get pluginStorageTitle => 'Bộ nhớ riêng của plugin';

  @override
  String pluginStorageUsage(String used, String limit) {
    return '$used / $limit';
  }

  @override
  String get pluginSavedLyricsTitle => 'Lời đã lưu từ nguồn này';

  @override
  String get pluginSavedLyricsNone => 'Chưa có';

  @override
  String pluginSavedLyricsSummary(int count, String size) {
    return '$count bài · $size';
  }

  @override
  String get pluginDataClear => 'Xóa';

  @override
  String get pluginStorageClearTitle => 'Xóa bộ nhớ riêng của plugin?';

  @override
  String get pluginStorageClearBody =>
      'Plugin có thể phải đăng nhập hoặc thiết lập lại.';

  @override
  String get pluginStorageCleared => 'Đã xóa bộ nhớ riêng';

  @override
  String get pluginSavedLyricsClearTitle => 'Xóa lời đã lưu từ nguồn này?';

  @override
  String get pluginSavedLyricsClearBody =>
      'Lời đã lưu từ nguồn này sẽ bị xóa. Lời đã ghim và file .lrc vẫn giữ.';

  @override
  String get pluginSavedLyricsCleared => 'Đã xóa lời đã lưu';

  @override
  String get pluginDataFailed => 'Không xóa được dữ liệu';

  @override
  String pluginUninstallTitle(String name) {
    return 'Gỡ $name?';
  }

  @override
  String get pluginUninstallRemoves => 'Sẽ bị xóa';

  @override
  String get pluginUninstallKeeps => 'Vẫn giữ';

  @override
  String get pluginUninstallCode => 'Code của plugin';

  @override
  String get pluginUninstallSettings => 'Cài đặt của plugin';

  @override
  String get pluginUninstallSettingsSecret =>
      'Cài đặt của plugin, kể cả giá trị bí mật trong kho khóa';

  @override
  String pluginUninstallStorage(String size) {
    return 'Bộ nhớ riêng ($size)';
  }

  @override
  String pluginUninstallKeepLyrics(int count) {
    return 'Lời đã lưu của $count bài và lời đã ghim từ nguồn này';
  }

  @override
  String get pluginUninstallKeepPinned => 'Lời đã ghim từ nguồn này (nếu có)';

  @override
  String get pluginUninstallKeepLrc => 'File .lrc đã ghi cạnh bài';

  @override
  String get pluginUninstallConfirm => 'Gỡ';

  @override
  String pluginUninstalled(String name) {
    return 'Đã gỡ $name';
  }

  @override
  String pluginUninstallFailed(String name) {
    return 'Không gỡ được $name';
  }

  @override
  String get pluginProblemTooLarge => 'Gói, hoặc một mục trong gói, quá lớn';

  @override
  String get pluginProblemNotZip => 'File không phải gói zip đọc được';

  @override
  String pluginProblemUnsafeEntry(String detail) {
    return 'Gói có tên mục không an toàn ($detail)';
  }

  @override
  String get pluginProblemTooManyEntries => 'Gói có quá nhiều file';

  @override
  String get pluginProblemMissingManifest => 'Không thấy plugin.json ở đầu gói';

  @override
  String pluginProblemInvalidManifest(String detail) {
    return 'Mục \"$detail\" trong plugin.json không hợp lệ';
  }

  @override
  String get pluginProblemInvalidManifestPlain => 'plugin.json không hợp lệ';

  @override
  String get pluginProblemNeedsNewerApp =>
      'Cần Kanaru mới hơn: plugin dùng API plugin mới hơn bản này hỗ trợ';

  @override
  String get pluginProblemWrongType => 'plugin.json: type phải là lyrics';

  @override
  String pluginProblemBadHost(String detail) {
    return 'hosts: \"$detail\" không phải tên miền công khai';
  }

  @override
  String pluginProblemMissingScript(String detail) {
    return 'Không thấy src/$detail trong gói';
  }

  @override
  String pluginProblemScriptError(String detail) {
    return 'Script $detail bị lỗi';
  }

  @override
  String pluginProblemScriptErrorLine(String detail, int line) {
    return 'Script $detail bị lỗi ở dòng $line';
  }

  @override
  String get pluginProblemCheckUnavailable =>
      'Kanaru chưa kiểm tra được script lúc này (thành phần chạy plugin không tải được) nên chưa biết gói có hợp lệ không';

  @override
  String get pluginRefusedNotFromRepo =>
      'Plugin này cài từ file nên không có cập nhật. Hãy gỡ rồi cài file mới.';

  @override
  String get pluginRefusedOlderVersion =>
      'Gói này cũ hơn bản đã cài nên không được dùng.';

  @override
  String get pluginInstallSecretsUnavailable =>
      'Không xóa được các giá trị bí mật của lần cài trước khỏi kho khóa nên chưa cài lại plugin. Hãy mở khóa kho khóa hoặc khởi động lại Kanaru rồi thử lại.';

  @override
  String get pluginInstallGone =>
      'Plugin này không còn được cài nên không cập nhật được.';

  @override
  String get pluginConfigSaveFailed => 'Không lưu được cài đặt';

  @override
  String get pluginConfigLoadFailed => 'Không đọc được cài đặt của plugin';

  @override
  String get pluginSourcesLoadFailed => 'Không đọc được danh sách plugin';

  @override
  String get pluginRetry => 'Thử lại';

  @override
  String lyricsSourceNameRemoved(String name) {
    return '$name (đã gỡ)';
  }

  @override
  String lyricsSourceNameWithAuthor(String name, String author) {
    return '$name · $author';
  }

  @override
  String lyricsPickerAllSources(int count) {
    return 'Mọi nguồn ($count)';
  }

  @override
  String get lyricsPickerSourceMenuAll => 'Mọi nguồn';

  @override
  String lyricsPickerSourceFilterLabel(String source) {
    return 'Lọc theo nguồn: $source';
  }

  @override
  String get lyricsViewLog => 'Xem log';

  @override
  String get lyricsStoreTitle => 'Kho plugin';

  @override
  String get lyricsStoreSearchHint => 'Tìm theo tên, tác giả, repo, host';

  @override
  String get lyricsStoreChipAll => 'Tất cả';

  @override
  String get lyricsStoreFromFile => 'Từ file';

  @override
  String lyricsStoreSectionUpdates(int count) {
    return 'Cập nhật ($count)';
  }

  @override
  String lyricsStoreSectionInstalled(int count) {
    return 'Đã cài ($count)';
  }

  @override
  String lyricsStoreSectionAvailable(int count) {
    return 'Chưa cài ($count)';
  }

  @override
  String get lyricsStoreUpdateAll => 'Cập nhật tất cả';

  @override
  String get lyricsStoreNoMatch => 'Không có plugin khớp.';

  @override
  String lyricsStoreNeedsNewerFooter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plugin cần Kanaru mới hơn',
    );
    return '$_temp0';
  }

  @override
  String lyricsStoreRepoFailedOne(String name, String reason) {
    return 'Không tải được $name: $reason';
  }

  @override
  String lyricsStoreRepoFailedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count repository không tải được',
    );
    return '$_temp0';
  }

  @override
  String get lyricsStoreRetry => 'Thử lại';

  @override
  String get lyricsStoreLoadNetwork => 'lỗi mạng';

  @override
  String get lyricsStoreLoadNotFound => 'không tìm thấy file';

  @override
  String get lyricsStoreLoadTooLarge => 'file quá lớn';

  @override
  String get lyricsStoreLoadInvalid => 'không phải danh sách plugin hợp lệ';

  @override
  String get lyricsStoreLoadBlocked => 'địa chỉ bị chặn';

  @override
  String get lyricsStoreInstallTooltip => 'Cài';

  @override
  String get lyricsStoreUpdateTooltip => 'Cập nhật';

  @override
  String get lyricsStoreUninstallTooltip => 'Gỡ plugin';

  @override
  String get lyricsStoreWorking => 'Đang xử lý';

  @override
  String get lyricsStoreMenuInstallFile => 'Cài từ file…';

  @override
  String lyricsStoreMenuRepositories(int count) {
    return 'Repository ($count)';
  }

  @override
  String get lyricsStoreMenuRefreshAll => 'Làm mới tất cả';

  @override
  String get lyricsStoreEmptyTitle => 'Chưa có plugin nào';

  @override
  String get lyricsStoreAddRepository => 'Thêm repository';

  @override
  String get lyricsStoreUnavailable => 'Kho plugin chưa dùng được lúc này.';

  @override
  String get lyricsStoreLoadFailed => 'Không đọc được kho plugin';

  @override
  String lyricsStoreInstalled(String name) {
    return 'Đã cài $name';
  }

  @override
  String get lyricsStoreUndo => 'Hoàn tác';

  @override
  String get lyricsStoreUndoFailed => 'Không hoàn tác được';

  @override
  String lyricsStoreUpdated(String name, int version) {
    return 'Đã cập nhật $name lên v$version';
  }

  @override
  String lyricsStoreUpdatedAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã cập nhật $count plugin',
    );
    return '$_temp0';
  }

  @override
  String lyricsStoreUpdatedAllPartial(int done, int failed) {
    return 'Đã cập nhật $done plugin, $failed plugin lỗi';
  }

  @override
  String lyricsStoreUninstalled(String name) {
    return 'Đã gỡ $name';
  }

  @override
  String lyricsStoreUninstallFailed(String name) {
    return 'Không gỡ được $name';
  }

  @override
  String get lyricsStoreInstallFailedTitle => 'Không cài được';

  @override
  String lyricsStoreInstallFailedFile(String name) {
    return 'File $name không phải plugin hợp lệ.';
  }

  @override
  String lyricsStoreInstallFailedRepo(String name, String repo) {
    return '$name · Repo: $repo';
  }

  @override
  String get lyricsStoreReasons => 'Lý do';

  @override
  String get lyricsStoreMismatchTitle => 'Gói không khớp danh sách';

  @override
  String get lyricsStoreMismatchDiffs => 'Điểm khác biệt';

  @override
  String lyricsStoreMismatchVersion(int catalog, int package) {
    return 'Danh sách ghi phiên bản $catalog, gói tải về là phiên bản $package';
  }

  @override
  String lyricsStoreMismatchHosts(String catalog, String package) {
    return 'Danh sách ghi host $catalog, gói khai báo $package';
  }

  @override
  String get lyricsStoreMismatchGeneric =>
      'Phiên bản hoặc host của gói khác với danh sách';

  @override
  String get lyricsStoreMismatchHint =>
      'Thường do repository vừa được cập nhật và cache chưa kịp đổi. Hãy làm mới danh sách rồi thử lại sau vài phút. Nếu vẫn khác, hãy báo cho chủ repository.';

  @override
  String get lyricsStoreMismatchRetry => 'Làm mới rồi thử lại';

  @override
  String get lyricsStoreNeedsNewerTitle => 'Cần Kanaru mới hơn';

  @override
  String lyricsStoreNeedsNewerBody(String name) {
    return '$name dùng API plugin mới hơn bản Kanaru này hỗ trợ. Hãy cập nhật Kanaru rồi cài lại.';
  }

  @override
  String get lyricsStoreFailUnknownRepo =>
      'Repository này không còn trong danh sách';

  @override
  String get lyricsStoreFailUnknownEntry =>
      'Repository không còn liệt kê plugin này. Hãy làm mới danh sách.';

  @override
  String get lyricsStoreFailNoNewerVersion => 'Chưa có phiên bản mới hơn';

  @override
  String lyricsStoreFailDownload(String reason) {
    return 'Không tải được gói plugin: $reason';
  }

  @override
  String get lyricsStoreFailRejected => 'Gói plugin không hợp lệ';

  @override
  String get lyricsStoreFailMismatch => 'Gói không khớp danh sách';

  @override
  String get lyricsStoreFailStorage =>
      'Không ghi được plugin vào ổ đĩa (đĩa đầy hoặc thiếu quyền?)';

  @override
  String get lyricsStoreFailUnexpected => 'Đã xảy ra lỗi. Hãy thử lại.';

  @override
  String lyricsStoreAlreadyGone(String name) {
    return '$name đã được gỡ từ trước';
  }

  @override
  String get lyricsStoreFailPackageTooLarge => 'gói quá lớn';

  @override
  String lyricsStoreItemAuthor(String author) {
    return '$author (tự khai báo)';
  }

  @override
  String get lyricsStoreItemUnknownAuthor => 'Không rõ tác giả';

  @override
  String get lyricsStoreItemInfo => 'Chi tiết';

  @override
  String get lyricsStoreItemDescription => 'Mô tả';

  @override
  String get lyricsStoreItemRepo => 'Repository';

  @override
  String get lyricsStoreItemHosts => 'Chỉ được kết nối tới';

  @override
  String get lyricsStoreItemInstall => 'Cài';

  @override
  String get lyricsStoreItemNotFound =>
      'Không thấy plugin này trong repository.';

  @override
  String get lyricsStoreReposTitle => 'Repository';

  @override
  String get lyricsStoreReposEmpty => 'Chưa có repository nào.';

  @override
  String lyricsStoreRepoErrorTooltip(String reason) {
    return 'Lần tải gần nhất bị lỗi: $reason';
  }

  @override
  String get lyricsStoreRepoRemoveTooltip => 'Gỡ repository';

  @override
  String lyricsStoreRemoveRepoTitle(String name) {
    return 'Gỡ $name?';
  }

  @override
  String get lyricsStoreRemoveRepoBody =>
      'Plugin đã cài từ repository này vẫn được giữ, nhưng sẽ không còn nhận cập nhật.';

  @override
  String get lyricsStoreRemoveRepoConfirm => 'Gỡ';

  @override
  String lyricsStoreRepoRemoved(String name) {
    return 'Đã gỡ $name';
  }

  @override
  String lyricsStoreRepoRemoveFailed(String name) {
    return 'Không gỡ được $name';
  }

  @override
  String get lyricsStoreAddUrlLabel => 'URL';

  @override
  String get lyricsStoreAddConfirm => 'Thêm';

  @override
  String get lyricsStoreAddLoading => 'Đang tải…';

  @override
  String lyricsStoreAddedRepo(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã thêm $name · $count plugin',
    );
    return '$_temp0';
  }

  @override
  String get lyricsStoreAddErrPublicNeedsHttps => 'Địa chỉ công khai cần https';

  @override
  String get lyricsStoreAddErrInvalidUrl => 'URL không hợp lệ';

  @override
  String get lyricsStoreAddErrDuplicate => 'Repository này đã được thêm';

  @override
  String get lyricsStoreAddErrNetwork => 'Không tải được danh sách: lỗi mạng';

  @override
  String get lyricsStoreAddErrNotFound =>
      'Không thấy danh sách plugin ở địa chỉ này';

  @override
  String get lyricsStoreAddErrBadFormat =>
      'File không phải danh sách plugin hợp lệ';

  @override
  String get lyricsStoreAddErrBlocked => 'Địa chỉ này bị chặn';

  @override
  String lyricsStoreAddErrBlockedReason(String reason) {
    return 'Địa chỉ này bị chặn: $reason';
  }

  @override
  String get lyricsStoreAddErrStorage => 'Không lưu được repository';

  @override
  String get lyricsStoreAddressUserInfo =>
      'địa chỉ không được chứa tên người dùng hay mật khẩu';

  @override
  String get lyricsStoreAddressLocalFromPublic =>
      'repository công khai không được trỏ tới địa chỉ cục bộ';

  @override
  String get lyricsStoreAddressRefused =>
      'địa chỉ này không được phép truy cập';

  @override
  String get lyricsStoreAddressMixed =>
      'tên miền trỏ tới cả địa chỉ cục bộ và công khai';

  @override
  String get lyricsStoreAddressLocalNamePublic =>
      'tên trông như cục bộ lại trỏ tới địa chỉ công khai';

  @override
  String get lyricsStoreItemInstalled => 'Đã cài';

  @override
  String get lyricsStoreItemOpenInstalled => 'Mở';

  @override
  String get contextModalBack => 'Quay lại';

  @override
  String get contextModalClose => 'Đóng';

  @override
  String get contextModalLabel => 'Menu';

  @override
  String get contextModalComingSoon => 'Sắp có';

  @override
  String get contextModalComingSoonSnack =>
      'Tính năng này chưa có. Sắp ra mắt.';

  @override
  String get songModalLabel => 'Tùy chọn bài hát';

  @override
  String get songModalMoreOptions => 'Tùy chọn khác';

  @override
  String get songModalGoToAlbum => 'Đi tới album';

  @override
  String get songModalGoToArtist => 'Đi tới nghệ sĩ';

  @override
  String get songModalGoToAlbumArtist => 'Đi tới nghệ sĩ album';

  @override
  String get songModalGoToFolder => 'Đi tới thư mục';

  @override
  String get songModalNoAlbum => 'Không có album';

  @override
  String get songModalNoArtist => 'Không có nghệ sĩ';

  @override
  String get songModalUnknownAlbum => 'Album không rõ';

  @override
  String get songModalEditTags => 'Chỉnh sửa thẻ';

  @override
  String get songModalAdvanced => 'Nâng cao';

  @override
  String get songModalRemoveFromLibrary => 'Loại khỏi thư viện';

  @override
  String get songModalDeleteFile => 'Xoá tệp khỏi ổ đĩa';

  @override
  String songModalArtistsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nghệ sĩ',
    );
    return '$_temp0';
  }

  @override
  String get songInfoTitle => 'Thông tin bài hát';

  @override
  String get songInfoShowUnknown => 'Hiện trường không xác định';

  @override
  String get songInfoHideUnknown => 'Ẩn trường không xác định';

  @override
  String get songInfoPreview => 'Nghe thử đoạn hay nhất · sắp có';

  @override
  String songInfoPlays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Tổng lượt nghe: $countString';
  }

  @override
  String songInfoFirstPlayed(String date) {
    return 'Nghe lần đầu: $date';
  }

  @override
  String songInfoLastPlayed(String date) {
    return 'Nghe gần nhất: $date';
  }

  @override
  String get songInfoNeverPlayed => 'Chưa nghe lần nào';

  @override
  String get songInfoGroupTags => 'Thẻ';

  @override
  String get songInfoGroupAudio => 'Âm thanh';

  @override
  String get songInfoGroupFile => 'Tệp';

  @override
  String get songInfoLabelTitle => 'Tiêu đề';

  @override
  String get songInfoLabelArtist => 'Nghệ sĩ';

  @override
  String get songInfoLabelAlbum => 'Album';

  @override
  String get songInfoLabelAlbumArtist => 'Nghệ sĩ album';

  @override
  String get songInfoLabelGenre => 'Thể loại';

  @override
  String get songInfoLabelComposer => 'Nhà soạn nhạc';

  @override
  String get songInfoLabelReleaseDate => 'Ngày phát hành';

  @override
  String get songInfoLabelTrack => 'Số bài';

  @override
  String get songInfoLabelDisc => 'Đĩa';

  @override
  String get songInfoLabelLanguage => 'Ngôn ngữ';

  @override
  String get songInfoLabelComment => 'Bình luận';

  @override
  String get songInfoLabelDuration => 'Thời lượng';

  @override
  String get songInfoLabelFormat => 'Định dạng';

  @override
  String get songInfoLabelBitrate => 'Tốc độ bit';

  @override
  String get songInfoLabelSampleRate => 'Tần số lấy mẫu';

  @override
  String get songInfoLabelBitDepth => 'Độ sâu bit';

  @override
  String get songInfoLabelChannels => 'Kênh';

  @override
  String get songInfoLabelPath => 'Đường dẫn';

  @override
  String get songInfoLabelSize => 'Dung lượng';

  @override
  String get songInfoLabelModified => 'Ngày sửa';

  @override
  String get songInfoLabelAdded => 'Ngày thêm';

  @override
  String get songInfoUnknown => 'Không xác định';

  @override
  String songInfoCopied(String value) {
    return 'Đã sao chép: $value';
  }

  @override
  String get songInfoCopy => 'Sao chép';

  @override
  String songInfoYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count năm trước',
      zero: 'năm nay',
    );
    return '$_temp0';
  }

  @override
  String songInfoChannelsMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kênh',
    );
    return '$_temp0';
  }

  @override
  String get songInfoMono => 'Mono';

  @override
  String get songInfoStereo => 'Stereo';

  @override
  String songInfoKbps(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString kbps';
  }

  @override
  String songInfoKhz(String value) {
    return '$value kHz';
  }

  @override
  String songInfoBits(int count) {
    return '$count bit';
  }

  @override
  String songInfoFileSizeMb(String value) {
    return '$value MB';
  }

  @override
  String get songInfoGone => 'Bài hát này không còn trong thư viện';

  @override
  String get songInfoLoadFailed => 'Không tải được thông tin bài hát';

  @override
  String songInfoFileSizeGb(String value) {
    return '$value GB';
  }

  @override
  String get songLyricsTitle => 'Lời bài hát';

  @override
  String songLyricsPageTitle(String title) {
    return 'Lời · $title';
  }

  @override
  String songLyricsViewAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dòng',
    );
    return 'Xem toàn bộ · $_temp0';
  }

  @override
  String get songLyricsSidecar => 'Tệp .lrc';

  @override
  String get songLyricsEmbedded => 'Nhúng trong thẻ';

  @override
  String songLyricsOnline(String name) {
    return 'Online · $name';
  }

  @override
  String get songLyricsSynced => 'Đồng bộ';

  @override
  String get songLyricsNone => 'Không có lời';

  @override
  String get songLyricsFindOnline => 'Tìm online';

  @override
  String get songLyricsShowTimestamps => 'Hiện mốc thời gian';

  @override
  String get songLyricsHideTimestamps => 'Ẩn mốc thời gian';

  @override
  String get songLyricsCopy => 'Sao chép lời';

  @override
  String get songLyricsCopied => 'Đã sao chép lời bài hát';
}
