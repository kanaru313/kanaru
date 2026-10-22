import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/playlist_cover.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'playlist_display_name.dart';

enum _PlaylistAction { rename, delete }

/// Collage, name, song count, a Play button, the queue menu and a
/// rename / delete menu. The menu holds only the actions given; with none
/// it is left out.
class PlaylistHeader extends StatelessWidget {
  const PlaylistHeader({
    super.key,
    required this.page,
    this.onPlay,
    this.onQueueAction,
    this.onRename,
    this.onDelete,
  });

  final PlaylistPage page;

  /// Null while nothing in the playlist can play: Play is disabled.
  final VoidCallback? onPlay;

  /// Null hides the queue menu (nothing to enqueue).
  final ValueChanged<QueueAction>? onQueueAction;

  /// Null leaves the item out of the menu (the Favorites playlist).
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final queueAction = onQueueAction;
    final rename = onRename;
    final delete = onDelete;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < pageHeaderCompactWidth;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PlaylistCover(
                coverKeys: page.coverKeys,
                size: compact ? 112 : 160,
                seed: 'playlist:${page.playlist.id}',
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlistDisplayName(page.playlist, l10n),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.playlistTrackCount(page.playlist.entryCount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        FilledButton.icon(
                          onPressed: onPlay,
                          icon: const Icon(AppIcons.play),
                          label: Text(l10n.albumsPlay),
                        ),
                        if (queueAction != null)
                          QueueActionsButton(onSelected: queueAction),
                        if (rename != null || delete != null)
                          PopupMenuButton<_PlaylistAction>(
                            tooltip: l10n.playlistActions,
                            // Not the kebab of the queue menu beside it.
                            icon: const Icon(AppIcons.edit),
                            onSelected: (action) => switch (action) {
                              _PlaylistAction.rename => rename?.call(),
                              _PlaylistAction.delete => delete?.call(),
                            },
                            itemBuilder: (context) => [
                              if (rename != null)
                                PopupMenuItem(
                                  value: _PlaylistAction.rename,
                                  child: Text(l10n.playlistRename),
                                ),
                              if (delete != null)
                                PopupMenuItem(
                                  value: _PlaylistAction.delete,
                                  child: Text(l10n.playlistDelete),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
