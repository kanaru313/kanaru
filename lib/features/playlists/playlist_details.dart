import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../core/m3u/m3u_write.dart' show M3uPathStyle;
import '../../l10n/l10n.dart';
import '../../shared/widgets/detail_page/play_shuffle_actions.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'playlist_actions_menu.dart';
import 'playlist_display_name.dart';

/// Name (bold, two lines at most), song count, then Play / Shuffle and one
/// "more" menu with rename, export, the queue actions and delete
/// ([PlaylistActionsMenu]). Shared by the narrow header and the side pane of
/// a playlist page. The menu holds only the actions given; with none it is
/// left out.
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
    final menu = PlaylistActionsMenu(
      onQueueAction: onQueueAction,
      onRename: onRename,
      onDelete: onDelete,
      onExport: onExport,
    );

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
                onQueueAction: null,
                menu: menu.hasItems ? menu : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
