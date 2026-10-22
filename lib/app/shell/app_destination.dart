import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';

/// Top-level pages of the app. Each one is a branch of the shell route (in
/// this order), so it keeps its own navigation stack.
enum AppDestination {
  home('/home', AppIcons.homeOutlined, AppIcons.home),
  songs('/songs', AppIcons.musicNoteOutlined, AppIcons.musicNote),
  albums('/albums', AppIcons.albumOutlined, AppIcons.album),
  artists('/artists', AppIcons.artistOutline, AppIcons.artist),
  genres('/genres', AppIcons.genreOutlined, AppIcons.genre),
  folders('/folders', AppIcons.folderOutlined, AppIcons.folder),
  favorites('/favorites', AppIcons.favoriteOutline, AppIcons.favorite),
  recentlyPlayed('/recent', AppIcons.history, AppIcons.history),
  playlists('/playlists', AppIcons.playlistOutlined, AppIcons.playlist),
  search('/search', AppIcons.search, AppIcons.search),
  settings('/settings', AppIcons.settingsOutlined, AppIcons.settings);

  const AppDestination(this.path, this.icon, this.selectedIcon);

  final String path;
  final IconData icon;
  final IconData selectedIcon;

  String label(AppLocalizations l10n) => switch (this) {
    home => l10n.navHome,
    songs => l10n.navSongs,
    albums => l10n.navAlbums,
    artists => l10n.navArtists,
    genres => l10n.genresTitle,
    folders => l10n.navFolders,
    favorites => l10n.navFavorites,
    recentlyPlayed => l10n.navRecentlyPlayed,
    playlists => l10n.sidebarPlaylists,
    search => l10n.navSearch,
    settings => l10n.navSettings,
  };
}

/// Destinations listed in the sidebar, grouped by dividers. Search and
/// settings are reached from the top bar instead; playlists have their own
/// section below the groups.
const sidebarGroups = [
  [AppDestination.home],
  [
    AppDestination.songs,
    AppDestination.albums,
    AppDestination.artists,
    AppDestination.genres,
    AppDestination.folders,
  ],
  [AppDestination.favorites, AppDestination.recentlyPlayed],
];
