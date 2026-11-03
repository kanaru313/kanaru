import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../shared/widgets/playlist_cover.dart';
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
    this.savedQueue = false,
    this.beforeRead,
  });

  final PlaylistPageHead head;

  /// Entries in the list now, which may differ from the head while an edit
  /// is on its way to the database.
  final int count;

  /// Null while nothing in the playlist can play: Play is disabled.
  final VoidCallback? onPlay;

  /// Null disables Shuffle.
  final VoidCallback? onShuffle;

  /// See `PlaylistDetails.savedQueue` and `PlaylistDetails.beforeRead`.
  final bool savedQueue;
  final Future<void> Function()? beforeRead;

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
              savedQueue: savedQueue,
              beforeRead: beforeRead,
            ),
          ),
        ],
      ),
    );
  }
}
