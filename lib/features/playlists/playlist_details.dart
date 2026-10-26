import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../core/m3u/m3u_write.dart' show M3uPathStyle;
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/detail_page/play_shuffle_actions.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'playlist_display_name.dart';

enum _PlaylistAction { rename, delete, exportAbsolute, exportRelative }

/// Name (bold, two lines at most), song count, then Play / Shuffle / queue
/// menu and the rename / delete / export menu. Shared by the narrow header
/// and the side pane of a playlist page. The edit menu holds only the actions
/// given; with none it is left out.
class PlaylistDetails extends StatelessWidget {
  const PlaylistDetails({
    super.key,
    required this.head,
    required this.count,
    required this.titleStyle,
    this.actionsAtEnd = false,
    this.onPlay,
    this.onShuffle,
    this.onQueueAction,
    this.onRename,
    this.onDelete,
    this.onExport,
  });

  final PlaylistPageHead head;

  /// Entries in the list now, which may differ from the head while an edit
  /// is on its way to the database.
  final int count;
  final TextStyle? titleStyle;

  /// Buttons at the right end of the column instead of the left.
  final bool actionsAtEnd;

  /// Null while nothing in the playlist can play: Play is disabled.
  final VoidCallback? onPlay;

  /// Null disables Shuffle.
  final VoidCallback? onShuffle;

  /// Null hides the queue menu (nothing to enqueue).
  final ValueChanged<QueueAction>? onQueueAction;

  /// Null leaves the item out of the menu (the Favorites playlist).
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  /// Saves the playlist as an M3U file with paths of the given style; null
  /// leaves the two export items out.
  final ValueChanged<M3uPathStyle>? onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final rename = onRename;
    final delete = onDelete;
    final export = onExport;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          playlistDisplayName(head.playlist, l10n),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.playlistTrackCount(count),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: actionsAtEnd ? WrapAlignment.end : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              PlayShuffleActions(
                playLabel: l10n.albumsPlay,
                onPlay: onPlay,
                onShuffle: onShuffle,
                onQueueAction: onQueueAction,
              ),
              if (rename != null || delete != null || export != null)
                PopupMenuButton<_PlaylistAction>(
                  tooltip: l10n.playlistActions,
                  // Not the kebab of the queue menu beside it.
                  icon: const Icon(AppIcons.edit),
                  onSelected: (action) => switch (action) {
                    _PlaylistAction.rename => rename?.call(),
                    _PlaylistAction.delete => delete?.call(),
                    _PlaylistAction.exportAbsolute => export?.call(
                      M3uPathStyle.absolute,
                    ),
                    _PlaylistAction.exportRelative => export?.call(
                      M3uPathStyle.relative,
                    ),
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
                    if (export != null) ...[
                      PopupMenuItem(
                        value: _PlaylistAction.exportAbsolute,
                        child: Text(l10n.playlistM3uExportAbsolute),
                      ),
                      PopupMenuItem(
                        value: _PlaylistAction.exportRelative,
                        child: Text(l10n.playlistM3uExportRelative),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
