import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_rows.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/add_to_playlist/create_playlist_prompt.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/library_loading.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'm3u_import_flow.dart';
import 'playlist_page_data.dart';
import 'playlist_routes.dart';
import 'playlist_screen_states.dart';
import 'playlists_grid.dart';
import 'playlists_list.dart';
import 'playlists_view_toggle.dart';

final _log = Logger('playlists');

/// `/playlists`: every playlist as a card, newest first, a button to create
/// one (which then opens it) and one to import an M3U file.
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

    final cardsAsync = ref.watch(playlistCardsProvider);
    final hasPlaylists = cardsAsync.asData?.value.isNotEmpty ?? false;
    final view = ref.watch(settingsProvider.select((s) => s.playlistsView));

    return PageScaffold(
      title: l10n.sidebarPlaylists,
      actions: [
        if (hasPlaylists) const PlaylistsViewToggle(),
        const _ImportM3uButton(),
        _NewPlaylistButton(onPressed: () => _create(ref, context)),
      ],
      body: cardsAsync.when(
        skipLoadingOnReload: true,
        skipError: true,
        loading: () => const LibraryLoading(),
        error: (error, stack) => EmptyState(
          icon: AppIcons.errorOutline,
          title: l10n.libraryUnavailableTitle,
          message: l10n.libraryUnavailableMessage,
        ),
        data: (cards) {
          if (cards.isEmpty) {
            return EmptyState(
              icon: AppIcons.playlist,
              title: l10n.sidebarNoPlaylists,
              message: l10n.playlistsEmptyMessage,
              action: FilledButton.icon(
                onPressed: () => _create(ref, context),
                icon: const Icon(AppIcons.add),
                label: Text(l10n.sidebarNewPlaylist),
              ),
            );
          }
          void open(PlaylistSummary playlist) =>
              context.go(playlistLocation(playlist.id));
          return switch (view) {
            AlbumsView.grid => PlaylistsGrid(cards: cards, onOpen: open),
            AlbumsView.list => PlaylistsList(cards: cards, onOpen: open),
          };
        },
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
        icon: const Icon(AppIcons.add),
        tooltip: label,
      );
    }
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: const Icon(AppIcons.add),
      label: Text(label),
    );
  }
}

/// The page's "Import M3U…" button; icon only on a narrow header. Disabled
/// while an import runs.
class _ImportM3uButton extends ConsumerStatefulWidget {
  const _ImportM3uButton();

  @override
  ConsumerState<_ImportM3uButton> createState() => _ImportM3uButtonState();
}

class _ImportM3uButtonState extends ConsumerState<_ImportM3uButton> {
  bool _busy = false;

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      await importM3uInteractively(ref, context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.playlistM3uImport;
    final onPressed = _busy ? null : _import;
    if (PageScaffold.compactActionsOf(context)) {
      return IconButton(
        onPressed: onPressed,
        icon: const Icon(AppIcons.importPlaylist),
        tooltip: label,
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(AppIcons.importPlaylist),
      label: Text(label),
    );
  }
}
