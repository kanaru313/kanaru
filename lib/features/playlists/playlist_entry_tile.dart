import 'package:material_ui/material_ui.dart';

import '../../core/database/library_rows.dart';
import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/song_modal/song_modal_data.dart';
import '../../shared/song_modal/song_modal_extras.dart';
import '../../shared/widgets/context_modal/context_modal_route.dart';
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
/// cover. With [onRemove] its song modal has a red Remove from playlist. An
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

  /// Null leaves Remove from playlist out (a read-only list, or Favorites).
  final VoidCallback? onRemove;

  /// Whether the drag handle shows; the list reorders only by it.
  final bool reorderable;

  /// Picked from the song modal; no modal without it.
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
    final remove = onRemove;
    return SongTile(
      song: track,
      onTap: onTap ?? () {},
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
                  label: context.l10n.playlistRemoveEntry,
                  destructive: true,
                  onTap: songModalCloseThen(remove),
                ),
              ],
            ),
    );
  }
}
