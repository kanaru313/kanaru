import 'package:material_ui/material_ui.dart';

import '../../core/settings/display_prefs.dart';
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
  languages('/languages', AppIcons.languageOutlined, AppIcons.language),
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
    languages => l10n.navLanguages,
    folders => l10n.navFolders,
    favorites => l10n.navFavorites,
    history => l10n.navHistory,
    queueHistory => l10n.queueHistoryTitle,
    playlists => l10n.sidebarPlaylists,
    search => l10n.navSearch,
    settings => l10n.navSettings,
  };
}

/// Library pages the user can hide, in the order the sidebar lists them
/// (not the order of [SidebarTab]).
const sidebarLibraryOrder = <AppDestination>[
  AppDestination.songs,
  AppDestination.albums,
  AppDestination.artists,
  AppDestination.genres,
  AppDestination.languages,
  AppDestination.folders,
];

/// The setting that shows or hides [destination] in the sidebar, or `null`
/// for pages that are always listed (or not listed at all).
SidebarTab? sidebarTabOf(AppDestination destination) => switch (destination) {
  AppDestination.songs => SidebarTab.songs,
  AppDestination.albums => SidebarTab.albums,
  AppDestination.artists => SidebarTab.artists,
  AppDestination.genres => SidebarTab.genres,
  AppDestination.languages => SidebarTab.languages,
  AppDestination.folders => SidebarTab.folders,
  AppDestination.home ||
  AppDestination.favorites ||
  AppDestination.history ||
  AppDestination.queueHistory ||
  AppDestination.playlists ||
  AppDestination.search ||
  AppDestination.settings => null,
};

/// Rows listed in the sidebar, grouped by dividers: Home; the library pages
/// whose tab is in [tabs]; queue history, favorites and history (always).
/// Search and settings are reached from the top bar instead; playlists have
/// their own section below the groups. A group left empty is dropped, so no
/// two dividers sit side by side.
List<List<AppDestination>> visibleSidebarGroups(Set<SidebarTab> tabs) {
  final library = [
    for (final d in sidebarLibraryOrder)
      if (tabs.contains(sidebarTabOf(d))) d,
  ];
  return [
    [AppDestination.home],
    if (library.isNotEmpty) library,
    [
      AppDestination.queueHistory,
      AppDestination.favorites,
      AppDestination.history,
    ],
  ];
}

/// Every page in the order it sits on screen, top to bottom: search and
/// settings (top bar, above the page area, search before settings left to
/// right), then the sidebar rows with every tab shown
/// ([visibleSidebarGroups] with all of [SidebarTab.values]), then playlists
/// last (its own section below the sidebar groups). This is only used to
/// rank destinations for [branchDirection]; the actual sidebar render order
/// (which hides tabs) stays [visibleSidebarGroups]. Hiding a tab only drops
/// it from the sidebar, it never reorders the rest, so this fixed order
/// matches the visible order for every subset of tabs.
final destinationScreenOrder = <AppDestination>[
  AppDestination.search,
  AppDestination.settings,
  ...visibleSidebarGroups(SidebarTab.values.toSet()).expand((g) => g),
  AppDestination.playlists,
];

/// Where [AppDestination.to] sits relative to [AppDestination.from] in
/// [destinationScreenOrder].
enum BranchDirection {
  /// `to` and `from` are the same destination.
  none,

  /// `to` sits below `from` in [destinationScreenOrder]; the new page
  /// arrives from below.
  towardsBelow,

  /// `to` sits above `from` in [destinationScreenOrder]; the new page
  /// arrives from above.
  towardsAbove,
}

/// Ranks [from] and [to] in [destinationScreenOrder] to tell which side the
/// new page sits on. Does not depend on which destinations are currently
/// visible in the sidebar: every destination has a fixed rank.
BranchDirection branchDirection(AppDestination from, AppDestination to) {
  if (from == to) return BranchDirection.none;
  final fromIndex = destinationScreenOrder.indexOf(from);
  final toIndex = destinationScreenOrder.indexOf(to);
  return toIndex > fromIndex
      ? BranchDirection.towardsBelow
      : BranchDirection.towardsAbove;
}
