import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_scaffold.dart';

/// The playlists pages when no library could be opened.
class PlaylistsUnavailable extends StatelessWidget {
  const PlaylistsUnavailable({super.key, this.title});

  /// The page title; null names the Playlists page.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: title ?? l10n.sidebarPlaylists,
      body: EmptyState(
        icon: AppIcons.errorOutline,
        title: l10n.libraryUnavailableTitle,
        message: l10n.libraryUnavailableMessage,
      ),
    );
  }
}

/// An empty playlist or saved queue, or the Favorites playlist before any
/// like.
class PlaylistEmptyState extends StatelessWidget {
  const PlaylistEmptyState({
    super.key,
    required this.favorites,
    this.savedQueue = false,
  });

  final bool favorites;
  final bool savedQueue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return favorites
        ? EmptyState(
            icon: AppIcons.favoriteOutline,
            title: l10n.navFavorites,
            message: l10n.favoritesEmptyMessage,
          )
        : savedQueue
        ? EmptyState(
            icon: AppIcons.playlist,
            title: l10n.queueHistoryEntriesEmptyTitle,
            message: l10n.queueHistoryEntriesEmptyMessage,
          )
        : EmptyState(
            icon: AppIcons.playlist,
            title: l10n.playlistEmptyTitle,
            message: l10n.playlistEmptyMessage,
          );
  }
}
