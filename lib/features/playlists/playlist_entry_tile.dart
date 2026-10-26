import 'package:material_ui/material_ui.dart';

import '../../core/database/library_rows.dart';
import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/hover_reveal_action.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import '../../shared/widgets/song_tile.dart';
import 'playlist_entry_handle.dart';
import 'playlist_missing_entry_tile.dart';

/// An entry used only to size the list's prototype row.
const prototypePlaylistEntry = PlaylistEntryRow(
  entryId: 0,
  path: '/prototype.flac',
  track: TrackListItem(
    id: 0,
    path: '/prototype.flac',
    title: 'Title',
    artist: 'Artist',
    album: 'Album',
    year: 2000,
    durationMs: 60000,
  ),
);

/// One playlist entry: the library song row with a drag handle before the
/// cover and a remove button at the end that shows on hover or focus. An
/// entry whose file is not in the library shows its file name, is dimmed and
/// does not play ([PlaylistMissingEntryTile]).
class PlaylistEntryTile extends StatelessWidget {
  const PlaylistEntryTile({
    super.key,
    required this.entry,
    required this.index,
    this.onTap,
    this.onRemove,
    this.reorderable = true,
    this.onQueueAction,
    this.favorites = false,
  });

  final PlaylistEntryRow entry;

  /// Position in the list as shown, for the drag handle.
  final int index;

  /// Plays from this row; null on an entry that cannot play.
  final VoidCallback? onTap;

  /// Null leaves the remove button out (a read-only list, or Favorites).
  final VoidCallback? onRemove;

  /// Whether the drag handle shows; the list reorders only by it.
  final bool reorderable;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  /// The list is Favorites: a missing entry without a remove button shows a
  /// heart so the liked file can still be taken out.
  final bool favorites;

  @override
  Widget build(BuildContext context) {
    final track = entry.track;
    if (track == null) {
      return PlaylistMissingEntryTile(
        entry: entry,
        index: index,
        reorderable: reorderable,
        onRemove: onRemove,
        showFavorite: favorites,
      );
    }
    Widget song(bool revealed) => SongTile(
      song: track,
      onTap: onTap ?? () {},
      onQueueAction: onQueueAction,
      leadingAccessory: reorderable ? PlaylistEntryHandle(index: index) : null,
      trailingAccessory: onRemove == null
          ? null
          : RevealableAction(
              revealed: revealed,
              child: IconButton(
                icon: const Icon(AppIcons.closeRounded),
                iconSize: 20,
                tooltip: context.l10n.playlistRemoveEntry,
                onPressed: onRemove,
              ),
            ),
    );
    return onRemove == null
        ? song(false)
        : HoverRevealAction(builder: (_, revealed) => song(revealed));
  }
}
