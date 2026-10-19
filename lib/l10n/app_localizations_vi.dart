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
  String get settingsEmptyMessage => 'Chưa có gì để cài đặt.';
}
