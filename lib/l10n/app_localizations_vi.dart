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
  String get navRecentlyPlayed => 'Phát gần đây';

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
  String libraryScanRootMissing(String path) {
    return 'Không tìm thấy $path';
  }

  @override
  String libraryScanRootEmpty(String path) {
    return '$path đang trống, giữ nguyên thư viện';
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
  String get favoritesEmptyMessage => 'Bài hát bạn thích sẽ hiện ở đây.';

  @override
  String get recentlyPlayedEmptyMessage => 'Bài hát bạn đã phát sẽ hiện ở đây.';

  @override
  String get searchEmptyTitle => 'Tìm trong thư viện';

  @override
  String get searchEmptyMessage => 'Tìm bài hát, album và nghệ sĩ.';

  @override
  String searchResultsTitle(String query) {
    return 'Kết quả cho “$query”';
  }

  @override
  String get searchNotReadyMessage =>
      'Tìm kiếm sẽ hoạt động khi thư viện đã được quét.';

  @override
  String get playerOpenMenu => 'Mở nhạc';

  @override
  String get playerOpenFiles => 'Mở file…';

  @override
  String get playerOpenFolder => 'Mở thư mục…';

  @override
  String get playerScanning => 'Đang quét thư mục…';

  @override
  String get playerNoAudioFound => 'Không tìm thấy file nhạc nào';

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
  String get nowPlayingComingSoon => 'Sắp có';

  @override
  String get nowPlayingTabQueue => 'Hàng đợi';

  @override
  String get nowPlayingTabTrack => 'Đang phát';

  @override
  String get queueOpen => 'Mở hàng đợi';

  @override
  String get queueTitle => 'Hàng đợi';

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
  String get queueShowCurrent => 'Đang phát';

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
}
