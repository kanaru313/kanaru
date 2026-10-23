import 'package:material_ui/material_ui.dart';

/// Every icon in the app, named by meaning. UI code never uses `Icons.` directly,
/// so the icon set or style can change in one place.
///
/// Entries that share a meaning but differ in glyph style (e.g. `play` and
/// `playRounded`) mirror what the UI used before this class existed. Unify them
/// when the icon style is chosen.
abstract final class AppIcons {
  // Transport and volume.
  static const IconData play = Icons.play_arrow;
  static const IconData playRounded = Icons.play_arrow_rounded;
  static const IconData pause = Icons.pause_rounded;
  static const IconData skipPrevious = Icons.skip_previous_rounded;
  static const IconData skipNext = Icons.skip_next_rounded;
  static const IconData shuffle = Icons.shuffle_rounded;
  static const IconData repeat = Icons.repeat_rounded;
  static const IconData repeatOne = Icons.repeat_one_rounded;
  static const IconData volumeUp = Icons.volume_up_rounded;
  static const IconData volumeDown = Icons.volume_down_rounded;
  static const IconData volumeOffRounded = Icons.volume_off_rounded;
  static const IconData volumeOff = Icons.volume_off;
  static const IconData equalizer = Icons.graphic_eq;
  static const IconData equalizerRounded = Icons.graphic_eq_rounded;
  static const IconData lyrics = Icons.lyrics_rounded;
  static const IconData dragHandle = Icons.drag_handle_rounded;
  static const IconData locateCurrent = Icons.my_location_rounded;

  // Library entities and placeholders.
  static const IconData musicNote = Icons.music_note;
  static const IconData musicNoteOutlined = Icons.music_note_outlined;
  static const IconData musicNoteRounded = Icons.music_note_rounded;
  static const IconData musicOff = Icons.music_off_outlined;
  static const IconData album = Icons.album;
  static const IconData albumOutlined = Icons.album_outlined;
  static const IconData artist = Icons.person;
  static const IconData artistOutline = Icons.person_outline;
  static const IconData artistRounded = Icons.person_rounded;
  static const IconData genre = Icons.category;
  static const IconData genreOutlined = Icons.category_outlined;
  static const IconData folder = Icons.folder;
  static const IconData folderOutlined = Icons.folder_outlined;
  static const IconData folderOpen = Icons.folder_open_outlined;
  static const IconData folderTree = Icons.account_tree_outlined;
  static const IconData folderFlat = Icons.format_list_bulleted;
  static const IconData folderOff = Icons.folder_off_outlined;
  static const IconData folderSpecial = Icons.folder_special_outlined;
  static const IconData addFolder = Icons.create_new_folder_outlined;
  static const IconData library = Icons.library_music_outlined;
  static const IconData addToPlaylist = Icons.library_add_outlined;
  static const IconData favorite = Icons.favorite;
  static const IconData favoriteOutline = Icons.favorite_outline;
  static const IconData favoriteBorderRounded = Icons.favorite_border_rounded;
  static const IconData history = Icons.history;

  // Queue and playlists.
  static const IconData playlist = Icons.queue_music;
  static const IconData playlistOutlined = Icons.queue_music_outlined;
  static const IconData queue = Icons.queue_music_rounded;
  static const IconData playlistPlay = Icons.playlist_play;
  static const IconData addToQueue = Icons.playlist_add;
  static const IconData newPlaylist = Icons.playlist_add;
  static const IconData playlistAddRounded = Icons.playlist_add_rounded;

  // Navigation and layout.
  static const IconData home = Icons.home;
  static const IconData homeOutlined = Icons.home_outlined;
  static const IconData settings = Icons.settings;
  static const IconData settingsOutlined = Icons.settings_outlined;
  static const IconData menu = Icons.menu;
  static const IconData chevronLeft = Icons.chevron_left;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData expandMore = Icons.expand_more;
  static const IconData expandMoreRounded = Icons.expand_more_rounded;
  static const IconData expandLess = Icons.expand_less;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData openExternal = Icons.open_in_new;
  static const IconData openFull = Icons.open_in_full;
  static const IconData viewGrid = Icons.grid_view;
  static const IconData viewList = Icons.view_list;
  static const IconData more = Icons.more_vert;
  static const IconData sortAscending = Icons.arrow_upward;
  static const IconData sortDescending = Icons.arrow_downward;

  // Actions.
  static const IconData search = Icons.search;
  static const IconData searchOff = Icons.search_off;
  static const IconData add = Icons.add;
  static const IconData remove = Icons.remove;
  static const IconData close = Icons.close;
  static const IconData closeRounded = Icons.close_rounded;
  static const IconData refresh = Icons.refresh;
  static const IconData edit = Icons.edit_outlined;
  static const IconData deleteOutline = Icons.delete_outline;
  static const IconData deleteRounded = Icons.delete_rounded;
  static const IconData clearAll = Icons.delete_sweep_rounded;

  // Status.
  static const IconData errorOutline = Icons.error_outline;
  static const IconData errorRounded = Icons.error_rounded;
  static const IconData warningOutlined = Icons.warning_amber_outlined;
  static const IconData warningRounded = Icons.warning_amber_rounded;
  static const IconData success = Icons.check_circle_rounded;

  // Settings and window chrome.
  static const IconData themeSystem = Icons.brightness_auto_outlined;
  static const IconData themeLight = Icons.light_mode_outlined;
  static const IconData themeDark = Icons.dark_mode_outlined;
  static const IconData language = Icons.translate;
  static const IconData windowCustom = Icons.web_asset;
  static const IconData windowSystem = Icons.desktop_windows_outlined;
  static const IconData windowFrameless = Icons.crop_free;
  static const IconData windowRestore = Icons.filter_none;
  static const IconData windowMaximize = Icons.crop_square;

  // History.
  static const IconData calendar = Icons.calendar_month_outlined;

  // Favorites and playlist files.
  static const IconData favoriteRounded = Icons.favorite_rounded;
  static const IconData importPlaylist = Icons.file_open_outlined;
  static const IconData saveQueue = Icons.playlist_add_check_rounded;

  // Queue history.
  static const IconData queueHistory = Icons.manage_history_rounded;
  static const IconData queueHistoryOutlined = Icons.manage_history_outlined;
  static const IconData currentQueue = Icons.queue_music_rounded;
  static const IconData currentQueueOutlined = Icons.queue_music_outlined;
}
