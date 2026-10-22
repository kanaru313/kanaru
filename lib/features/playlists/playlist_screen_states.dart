import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
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
        icon: Icons.error_outline,
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
        icon: Icons.queue_music,
        title: l10n.playlistNotFound,
        message: l10n.playlistNotFoundMessage,
      ),
    );
  }
}
