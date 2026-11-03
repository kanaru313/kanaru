import 'package:material_ui/material_ui.dart';

import '../../core/database/library_rows.dart';
import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/context_modal/context_modal_spec.dart';
import '../../shared/song_modal/song_modal_extras.dart';
import '../../shared/widgets/context_modal/context_modal_route.dart';
import '../../shared/widgets/hover_reveal_action.dart';
import '../../shared/widgets/missing_song_row.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import '../../shared/widgets/song_tile.dart';
import 'playlist_entry_handle.dart';

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
/// cover. With [onRemove] its song modal has a red Remove from playlist. An
/// entry whose file is not in the library is a [MissingSongRow]: no song
/// modal, a remove button shown on hover or focus with [onRemove], else a
/// heart on Favorites.
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
    this.savedQueue = false,
  });

  final PlaylistEntryRow entry;

  /// Position in the list as shown, for the drag handle.
  final int index;

  /// Plays from this row; null on an entry that cannot play.
  final VoidCallback? onTap;

  /// Null leaves Remove from playlist out (a read-only list, or Favorites).
  final VoidCallback? onRemove;

  /// Whether the drag handle shows; the list reorders only by it.
  final bool reorderable;

  /// Picked from the song modal; no modal without it.
  final ValueChanged<QueueAction>? onQueueAction;

  /// The list is Favorites: a missing entry without a remove button shows a
  /// heart so the liked file can still be taken out.
  final bool favorites;

  /// A saved queue: removal reads Remove from queue.
  final bool savedQueue;

  @override
  Widget build(BuildContext context) {
    final track = entry.track;
    if (track == null) return _missing(context);
    final remove = onRemove;
    return SongTile(
      song: track,
      // Only the first copy of the playing song is marked.
      playing: entry.repeat ? false : null,
      onTap: onTap,
      onQueueAction: onQueueAction,
      leadingAccessory: reorderable ? PlaylistEntryHandle(index: index) : null,
      // Built when the modal opens, so the texts come from the row's context
      // at that moment.
      modalExtras: remove == null
          ? null
          : () => SongModalExtras(
              actions: [
                ContextModalAction(
                  id: 'remove-from-playlist',
                  icon: AppIcons.playlistRemove,
                  label: savedQueue
                      ? context.l10n.queueRemove
                      : context.l10n.playlistRemoveEntry,
                  destructive: true,
                  onTap: contextModalCloseThen(remove),
                ),
              ],
            ),
    );
  }

  Widget _missing(BuildContext context) {
    final handle = reorderable ? PlaylistEntryHandle(index: index) : null;
    final remove = onRemove;
    if (remove == null) {
      return MissingSongRow(
        path: entry.path,
        leading: handle,
        // Favorites: the liked file can still be taken out.
        showFavorite: favorites,
      );
    }
    final l10n = context.l10n;
    return HoverRevealAction(
      builder: (_, revealed) => MissingSongRow(
        path: entry.path,
        leading: handle,
        trailing: RevealableAction(
          revealed: revealed,
          child: IconButton(
            icon: const Icon(AppIcons.closeRounded),
            iconSize: 20,
            tooltip: savedQueue ? l10n.queueRemove : l10n.playlistRemoveEntry,
            onPressed: remove,
          ),
        ),
      ),
    );
  }
}
