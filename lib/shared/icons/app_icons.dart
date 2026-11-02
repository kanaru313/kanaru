import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';

/// Every icon in the app, named by meaning. UI code never uses `Icons.` directly,
/// so the icon set or style can change in one place.
///
/// Configured to use Fluent System Icons (by Microsoft, MIT License).
abstract final class AppIcons {
  // Transport and volume.
  static const IconData play = FluentIcons.play_24_filled;
  static const IconData playRounded = FluentIcons.play_24_filled;
  static const IconData pause = FluentIcons.pause_24_filled;
  static const IconData skipPrevious = FluentIcons.previous_24_filled;
  static const IconData skipNext = FluentIcons.next_24_filled;
  static const IconData shuffle = FluentIcons.arrow_shuffle_24_regular;
  static const IconData repeat = FluentIcons.arrow_repeat_all_24_regular;
  static const IconData repeatOne = FluentIcons.arrow_repeat_1_24_regular;
  static const IconData repeatStopAtEnd =
      FluentIcons.text_bullet_list_square_24_regular;
  static const IconData volumeUp = FluentIcons.speaker_2_24_regular;
  static const IconData volumeDown = FluentIcons.speaker_1_24_regular;
  static const IconData volumeOffRounded = FluentIcons.speaker_off_24_regular;
  static const IconData volumeOff = FluentIcons.speaker_off_24_regular;
  static const IconData equalizer = FluentIcons.options_24_regular;
  static const IconData equalizerRounded = FluentIcons.options_24_regular;
  static const IconData lyrics = FluentIcons.subtitles_24_regular;
  static const IconData viewSplit = FluentIcons.layout_column_two_24_regular;
  static const IconData viewCover = FluentIcons.image_24_regular;
  static const IconData dragHandle =
      FluentIcons.re_order_dots_vertical_24_regular;

  // Library entities and placeholders.
  static const IconData musicNote = FluentIcons.music_note_2_24_filled;
  static const IconData musicNoteOutlined = FluentIcons.music_note_2_24_regular;
  static const IconData musicNoteRounded = FluentIcons.music_note_2_24_regular;
  static const IconData musicOff = FluentIcons.music_note_off_2_24_regular;
  static const IconData album = FluentIcons.album_24_filled;
  static const IconData albumOutlined = FluentIcons.album_24_regular;
  static const IconData artist = FluentIcons.person_24_filled;
  static const IconData artistOutline = FluentIcons.person_24_regular;
  static const IconData artistRounded = FluentIcons.person_24_regular;
  static const IconData artists = FluentIcons.people_24_regular;
  static const IconData splitArtist = FluentIcons.branch_fork_24_regular;
  static const IconData albumArtist = FluentIcons.person_star_24_regular;
  static const IconData genre = FluentIcons.shapes_24_filled;
  static const IconData genreOutlined = FluentIcons.shapes_24_regular;
  static const IconData folder = FluentIcons.folder_24_filled;
  static const IconData folderOutlined = FluentIcons.folder_24_regular;
  static const IconData folderOpen = FluentIcons.folder_open_24_regular;
  static const IconData folderTree =
      FluentIcons.text_bullet_list_tree_24_regular;
  static const IconData folderFlat = FluentIcons.text_bullet_list_24_regular;
  static const IconData folderOff = FluentIcons.folder_prohibited_24_regular;
  static const IconData folderSpecial = FluentIcons.folder_lightning_24_regular;
  static const IconData addFolder = FluentIcons.folder_add_24_regular;
  static const IconData library = FluentIcons.library_24_regular;
  static const IconData addToPlaylist =
      FluentIcons.text_bullet_list_add_24_regular;
  static const IconData favorite = FluentIcons.heart_24_filled;
  static const IconData favoriteOutline = FluentIcons.heart_24_regular;
  static const IconData favoriteBorderRounded = FluentIcons.heart_24_regular;
  static const IconData history = FluentIcons.history_24_regular;
  static const IconData mostPlayed = FluentIcons.data_histogram_24_filled;
  static const IconData mostPlayedOutlined =
      FluentIcons.data_histogram_24_regular;

  // Queue and playlists.
  static const IconData playlist =
      FluentIcons.text_bullet_list_square_24_filled;
  static const IconData playlistOutlined =
      FluentIcons.text_bullet_list_square_24_regular;
  static const IconData queue = FluentIcons.reorder_20_regular;
  static const IconData playlistPlay = FluentIcons.music_note_2_play_20_regular;
  static const IconData playlistRemove =
      FluentIcons.text_bullet_list_dismiss_20_regular;
  static const IconData addToQueue =
      FluentIcons.text_bullet_list_add_24_regular;
  static const IconData newPlaylist =
      FluentIcons.text_bullet_list_add_24_regular;
  static const IconData playlistAddRounded =
      FluentIcons.text_bullet_list_add_24_regular;

  // Navigation and layout.
  static const IconData home = FluentIcons.home_24_filled;
  static const IconData homeOutlined = FluentIcons.home_24_regular;
  static const IconData settings = FluentIcons.settings_24_filled;
  static const IconData settingsOutlined = FluentIcons.settings_24_regular;
  static const IconData menu = FluentIcons.navigation_24_regular;
  static const IconData chevronLeft = FluentIcons.chevron_left_24_regular;
  static const IconData chevronRight = FluentIcons.chevron_right_24_regular;
  static const IconData expandMore = FluentIcons.chevron_down_24_regular;
  static const IconData expandMoreRounded = FluentIcons.chevron_down_24_regular;
  static const IconData back = FluentIcons.arrow_left_24_regular;
  static const IconData openExternal = FluentIcons.open_24_regular;
  static const IconData openFull = FluentIcons.arrow_maximize_24_regular;
  static const IconData viewGrid = FluentIcons.grid_24_regular;
  static const IconData viewList = FluentIcons.text_bullet_list_ltr_24_regular;
  static const IconData more = FluentIcons.more_vertical_24_regular;
  static const IconData moreHoriz = FluentIcons.more_horizontal_24_regular;
  static const IconData sortAscending = FluentIcons.arrow_sort_up_24_regular;
  static const IconData sortDescending = FluentIcons.arrow_sort_down_24_regular;
  static const IconData locateUp = FluentIcons.arrow_up_24_regular;
  static const IconData locateDown = FluentIcons.arrow_down_24_regular;

  // Actions.
  static const IconData search = FluentIcons.search_24_regular;
  static const IconData searchOff = FluentIcons.search_info_24_regular;
  static const IconData searchFields = FluentIcons.filter_24_regular;

  /// Opens the filters of a list (same glyph as [searchFields]).
  static const IconData filter = searchFields;
  static const IconData add = FluentIcons.add_24_regular;
  static const IconData remove = FluentIcons.subtract_24_regular;
  static const IconData close = FluentIcons.dismiss_24_regular;
  static const IconData closeRounded = FluentIcons.dismiss_24_regular;
  static const IconData refresh = FluentIcons.arrow_sync_24_regular;
  static const IconData edit = FluentIcons.edit_24_regular;
  static const IconData editTags = FluentIcons.tag_24_regular;
  static const IconData advanced = FluentIcons.code_24_regular;
  static const IconData visibility = FluentIcons.eye_24_regular;
  static const IconData visibilityOff = FluentIcons.eye_off_24_regular;
  static const IconData headphones = FluentIcons.headphones_24_regular;
  static const IconData schedule = FluentIcons.clock_24_regular;
  static const IconData copy = FluentIcons.copy_24_regular;
  static const IconData duplicatePlaylist =
      FluentIcons.document_multiple_24_regular;
  static const IconData exportFile =
      FluentIcons.document_arrow_right_24_regular;
  static const IconData removeDuplicates = FluentIcons.copy_select_24_regular;
  static const IconData removeMissing = FluentIcons.music_note_off_2_24_regular;
  static const IconData findOnline = FluentIcons.globe_24_regular;
  static const IconData previewPlay = FluentIcons.play_circle_24_regular;
  static const IconData removeFromLibrary = FluentIcons.delete_24_regular;
  static const IconData deleteOutline = FluentIcons.delete_24_regular;
  static const IconData deleteRounded = FluentIcons.delete_24_regular;
  static const IconData clearAll = FluentIcons.delete_dismiss_24_regular;

  // Status.
  static const IconData errorOutline = FluentIcons.error_circle_24_regular;
  static const IconData errorRounded = FluentIcons.error_circle_24_regular;
  static const IconData warningOutlined = FluentIcons.warning_24_regular;
  static const IconData warningRounded = FluentIcons.warning_24_regular;
  static const IconData success = FluentIcons.checkmark_circle_24_regular;
  static const IconData info = FluentIcons.info_24_regular;

  // Settings and window chrome.
  static const IconData settingsAppearance = FluentIcons.color_24_regular;
  static const IconData settingsPlayback = FluentIcons.play_circle_24_regular;
  static const IconData settingsData = FluentIcons.database_24_regular;
  static const IconData settingsAbout = FluentIcons.info_24_regular;
  static const IconData themeSystem = FluentIcons.desktop_24_regular;
  static const IconData themeLight = FluentIcons.weather_sunny_24_regular;
  static const IconData themeDark = FluentIcons.weather_moon_24_regular;
  static const IconData language = FluentIcons.translate_24_filled;
  static const IconData languageOutlined = FluentIcons.translate_24_regular;

  // Lyrics translation button: outlined while off, filled while on.
  static const IconData lyricsTranslateOutlined =
      FluentIcons.translate_24_regular;
  static const IconData lyricsTranslate = FluentIcons.translate_24_filled;
  static const IconData lyricsKeep = FluentIcons.bookmark_24_regular;
  static const IconData lyricsSave = FluentIcons.save_24_regular;
  static const IconData lyricsReject = FluentIcons.thumb_dislike_24_regular;
  static const IconData windowCustom = FluentIcons.window_24_regular;
  static const IconData windowSystem = FluentIcons.desktop_24_regular;
  static const IconData windowFrameless = FluentIcons.frame_24_regular;
  static const IconData windowRestore =
      FluentIcons.full_screen_minimize_24_regular;
  static const IconData windowMaximize =
      FluentIcons.full_screen_maximize_24_regular;

  // History.
  static const IconData calendar = FluentIcons.calendar_ltr_24_regular;

  // Favorites and playlist files.
  static const IconData favoriteRounded = FluentIcons.heart_24_filled;
  static const IconData importPlaylist = FluentIcons.arrow_download_24_regular;
  static const IconData exportPlaylist = FluentIcons.arrow_upload_24_regular;
  static const IconData saveQueue = FluentIcons.save_24_regular;

  // Queue history.
  static const IconData queueHistory = FluentIcons.stack_24_filled;
  static const IconData queueHistoryOutlined = FluentIcons.stack_24_regular;

  // Sleep timer.
  static const IconData sleepTimer = FluentIcons.timer_24_regular;
  static const IconData sleepTimerActive = FluentIcons.timer_24_filled;

  // Lyrics sources and the plugin store.
  static const IconData extension = FluentIcons.puzzle_piece_24_regular;
  static const IconData download = FluentIcons.arrow_download_24_regular;
  static const IconData updateAvailable =
      FluentIcons.arrow_circle_up_24_regular;
  static const IconData installFromFile = FluentIcons.document_add_24_regular;
  static const IconData repository = FluentIcons.server_24_regular;
  static const IconData dropDown = FluentIcons.chevron_down_24_regular;
  static const IconData check = FluentIcons.checkmark_24_regular;

  /// Edit an album's cover art.
  static const IconData editAlbumArt = FluentIcons.image_edit_24_regular;

  // Playlist dialog options.
  static const IconData moveDown = FluentIcons.arrow_down_24_regular;
  static const IconData playlistAddCheck =
      FluentIcons.checkmark_square_24_regular;
}
