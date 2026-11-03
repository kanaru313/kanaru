import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/detail_page/play_shuffle_actions.dart';
import 'playlist_display_name.dart';
import 'playlist_modal/playlist_description_box.dart';
import 'playlist_modal/playlist_more_button.dart';

/// Name (bold, two lines at most), song count, the description (three lines,
/// then it scrolls; left out when empty), then Play / Shuffle and one
/// "more" button: the playlist modal, or on a saved queue the Queue modal.
/// Shared by the narrow header and the side pane of a playlist page.
class PlaylistDetails extends StatelessWidget {
  const PlaylistDetails({
    super.key,
    required this.head,
    required this.count,
    required this.titleStyle,
    this.actionsAtEnd = false,
    this.onPlay,
    this.onShuffle,
    this.savedQueue = false,
    this.beforeRead,
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

  /// A saved queue: the ⋮ button opens the Queue modal; any other playlist
  /// gets the playlist modal.
  final bool savedQueue;

  /// Completes when no write of the entries is in flight; the modal awaits it
  /// before reading or writing the entries.
  final Future<void> Function()? beforeRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final menu = PlaylistMoreButton(
      playlist: head.playlist,
      coverKeys: head.coverKeys,
      showGoTo: false,
      savedQueue: savedQueue,
      beforeRead: beforeRead,
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
        // Hidden when empty; at most three lines tall, then it scrolls.
        if (head.playlist.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: PlaylistDescriptionBox(
                text: head.playlist.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
                maxLines: 3,
              ),
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
                menu: menu,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
