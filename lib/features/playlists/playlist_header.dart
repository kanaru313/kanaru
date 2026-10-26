import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../core/m3u/m3u_write.dart' show M3uPathStyle;
import '../../shared/widgets/playlist_cover.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'playlist_details.dart';

/// Header of a playlist page in a narrow window: collage beside the name,
/// song count and the buttons. A wide window shows `PlaylistSidePane`
/// instead.
class PlaylistHeader extends StatelessWidget {
  const PlaylistHeader({
    super.key,
    required this.head,
    required this.count,
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

  /// Null while nothing in the playlist can play: Play is disabled.
  final VoidCallback? onPlay;

  /// Null disables Shuffle.
  final VoidCallback? onShuffle;

  /// Null hides the queue menu (nothing to enqueue).
  final ValueChanged<QueueAction>? onQueueAction;

  /// Null leaves the item out of the menu (the Favorites playlist).
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  /// Null leaves the two export items out.
  final ValueChanged<M3uPathStyle>? onExport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Row(
        children: [
          PlaylistCover(
            coverKeys: head.coverKeys,
            size: 120,
            seed: 'playlist:${head.playlist.id}',
          ),
          const SizedBox(width: 24),
          Expanded(
            child: PlaylistDetails(
              head: head,
              count: count,
              titleStyle: Theme.of(context).textTheme.headlineMedium,
              onPlay: onPlay,
              onShuffle: onShuffle,
              onQueueAction: onQueueAction,
              onRename: onRename,
              onDelete: onDelete,
              onExport: onExport,
            ),
          ),
        ],
      ),
    );
  }
}
