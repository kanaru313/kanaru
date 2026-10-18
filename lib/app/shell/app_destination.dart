import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// Top-level pages of the app. Each one is a branch of the shell route (in
/// this order), so it keeps its own navigation stack.
enum AppDestination {
  home('/home', Icons.home_outlined, Icons.home),
  songs('/songs', Icons.music_note_outlined, Icons.music_note),
  albums('/albums', Icons.album_outlined, Icons.album),
  artists('/artists', Icons.person_outline, Icons.person),
  folders('/folders', Icons.folder_outlined, Icons.folder),
  favorites('/favorites', Icons.favorite_outline, Icons.favorite),
  recentlyPlayed('/recent', Icons.history, Icons.history),
  search('/search', Icons.search, Icons.search),
  settings('/settings', Icons.settings_outlined, Icons.settings);

  const AppDestination(this.path, this.icon, this.selectedIcon);

  final String path;
  final IconData icon;
  final IconData selectedIcon;

  String label(AppLocalizations l10n) => switch (this) {
    home => l10n.navHome,
    songs => l10n.navSongs,
    albums => l10n.navAlbums,
    artists => l10n.navArtists,
    folders => l10n.navFolders,
    favorites => l10n.navFavorites,
    recentlyPlayed => l10n.navRecentlyPlayed,
    search => l10n.navSearch,
    settings => l10n.navSettings,
  };
}

/// Destinations listed in the sidebar, grouped by dividers. Search and
/// settings are reached from the top bar instead.
const sidebarGroups = [
  [AppDestination.home],
  [
    AppDestination.songs,
    AppDestination.albums,
    AppDestination.artists,
    AppDestination.folders,
  ],
  [AppDestination.favorites, AppDestination.recentlyPlayed],
];
