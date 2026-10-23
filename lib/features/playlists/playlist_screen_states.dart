import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_scaffold.dart';

/// The playlists pages when no library could be opened.
class PlaylistsUnavailable extends StatelessWidget {
  const PlaylistsUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: l10n.sidebarPlaylists,
      body: EmptyState(
        icon: AppIcons.errorOutline,
        title: l10n.libraryUnavailableTitle,
        message: l10n.libraryUnavailableMessage,
      ),
    );
  }
}

/// A playlist route whose id is malformed or whose playlist is gone.
class PlaylistNotFound extends StatelessWidget {
  const PlaylistNotFound({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: l10n.sidebarPlaylists,
      body: EmptyState(
        icon: AppIcons.playlist,
        title: l10n.playlistNotFound,
        message: l10n.playlistNotFoundMessage,
      ),
    );
  }
}

/// An empty playlist, or the Favorites playlist before any like.
class PlaylistEmptyState extends StatelessWidget {
  const PlaylistEmptyState({super.key, required this.favorites});

  final bool favorites;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return favorites
        ? EmptyState(
            icon: AppIcons.favoriteOutline,
            title: l10n.navFavorites,
            message: l10n.favoritesEmptyMessage,
          )
        : EmptyState(
            icon: AppIcons.playlist,
            title: l10n.playlistEmptyTitle,
            message: l10n.playlistEmptyMessage,
          );
  }
}
