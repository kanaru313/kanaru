import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/playlist_cover.dart';
import '../../shared/widgets/queue_actions_menu.dart';

enum _PlaylistAction { rename, delete }

/// Collage, name, song count, a Play button, the queue menu and a
/// rename / delete menu.
class PlaylistHeader extends StatelessWidget {
  const PlaylistHeader({
    super.key,
    required this.page,
    this.onPlay,
    this.onQueueAction,
    required this.onRename,
    required this.onDelete,
  });

  final PlaylistPage page;

  /// Null while nothing in the playlist can play: Play is disabled.
  final VoidCallback? onPlay;

  /// Null hides the queue menu (nothing to enqueue).
  final ValueChanged<QueueAction>? onQueueAction;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final queueAction = onQueueAction;

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
                      page.playlist.name,
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
                          icon: const Icon(Icons.play_arrow),
                          label: Text(l10n.albumsPlay),
                        ),
                        if (queueAction != null)
                          QueueActionsButton(onSelected: queueAction),
                        PopupMenuButton<_PlaylistAction>(
                          tooltip: l10n.playlistActions,
                          onSelected: (action) => switch (action) {
                            _PlaylistAction.rename => onRename(),
                            _PlaylistAction.delete => onDelete(),
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _PlaylistAction.rename,
                              child: Text(l10n.playlistRename),
                            ),
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
