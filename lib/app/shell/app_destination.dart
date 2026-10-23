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
  history('/history', AppIcons.history, AppIcons.history),
  queueHistory(
    '/queue-history',
    AppIcons.queueHistoryOutlined,
    AppIcons.queueHistory,
  ),
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
    history => l10n.navHistory,
    queueHistory => l10n.queueHistoryTitle,
    playlists => l10n.sidebarPlaylists,
    search => l10n.navSearch,
    settings => l10n.navSettings,
  };
}

/// One row of the sidebar groups: a page, or an action.
sealed class SidebarEntry {
  const SidebarEntry();
}

/// A row that opens [destination].
class SidebarDestination extends SidebarEntry {
  const SidebarDestination(this.destination);

  final AppDestination destination;
}

/// "Current queue": opens and closes the queue side sheet of the shell, lit
/// while it is open. Not a page, so nothing else is unselected by it.
class SidebarCurrentQueue extends SidebarEntry {
  const SidebarCurrentQueue();
}

/// Rows listed in the sidebar, grouped by dividers. Search and settings are
/// reached from the top bar instead; playlists have their own section below
/// the groups.
const sidebarGroups = <List<SidebarEntry>>[
  [SidebarDestination(AppDestination.home)],
  [
    SidebarDestination(AppDestination.songs),
    SidebarDestination(AppDestination.albums),
    SidebarDestination(AppDestination.artists),
    SidebarDestination(AppDestination.genres),
    SidebarDestination(AppDestination.folders),
  ],
  [
    SidebarDestination(AppDestination.queueHistory),
    SidebarCurrentQueue(),
    SidebarDestination(AppDestination.favorites),
    SidebarDestination(AppDestination.history),
  ],
];
