import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/add_to_playlist/create_playlist_prompt.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/library_loading.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'playlist_page_data.dart';
import 'playlist_routes.dart';
import 'playlist_screen_states.dart';
import 'playlists_grid.dart';

final _log = Logger('playlists');

/// `/playlists`: every playlist as a card, newest first, and a button to
/// create one (which then opens it).
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  /// Asks for a name, creates the playlist and opens it.
  Future<void> _create(WidgetRef ref, BuildContext context) async {
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final created = await promptAndCreatePlaylist(
      context,
      db,
      messenger,
      context.l10n,
    );
    if (created != null) router.go(playlistLocation(created.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hasLibrary = ref.watch(libraryDatabaseProvider) != null;
    if (!hasLibrary) return const PlaylistsUnavailable();

    ref.listen(playlistCardsProvider, (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        _log.severe(
          'Reading the playlists failed',
          next.error,
          next.stackTrace,
        );
      }
    });

    return PageScaffold(
      title: l10n.sidebarPlaylists,
      actions: [_NewPlaylistButton(onPressed: () => _create(ref, context))],
      body: ref
          .watch(playlistCardsProvider)
          .when(
            skipLoadingOnReload: true,
            skipError: true,
            loading: () => const LibraryLoading(),
            error: (error, stack) => EmptyState(
              icon: Icons.error_outline,
              title: l10n.libraryUnavailableTitle,
              message: l10n.libraryUnavailableMessage,
            ),
            data: (cards) => PlaylistsGrid(
              cards: cards,
              onOpen: (playlist) => context.go(playlistLocation(playlist.id)),
              emptyAction: FilledButton.icon(
                onPressed: () => _create(ref, context),
                icon: const Icon(Icons.add),
                label: Text(l10n.sidebarNewPlaylist),
              ),
            ),
          ),
    );
  }
}

/// The page's "New playlist" button; icon only on a narrow header.
class _NewPlaylistButton extends StatelessWidget {
  const _NewPlaylistButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.sidebarNewPlaylist;
    if (PageScaffold.compactActionsOf(context)) {
      return IconButton.filledTonal(
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        tooltip: label,
      );
    }
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(label),
    );
  }
}
