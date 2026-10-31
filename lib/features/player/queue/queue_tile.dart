import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_track_of_path.dart';
import '../../../core/player/play_queue.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/playing_track_art.dart' show localPathOf;
import '../../../core/player/track.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/favorite_button.dart';
import '../../../shared/widgets/hover_reveal_action.dart';
import '../../../shared/widgets/library_row.dart';
import '../../../shared/widgets/song_row_view.dart';
import 'queue_play_next_marker.dart';
import 'queue_tile_menu.dart';

/// Largest text scale the fixed-height row's text grows to. The list sizes
/// its rows with the same cap (`songCardExtent`), so the three lines always
/// fit.
const queueTileMaxTextScale = 1.25;

/// Whether the row at [position] is one of the [upNextRun] "play next" rows
/// right after the playing one.
bool isUpNextRow(PlayQueue queue, int position, int upNextRun) =>
    position > queue.index && position <= queue.index + upNextRun;

/// Width of the drag handle (or of the gap that takes its place): 8 px
/// padding around a 20 px icon.
const _handleWidth = 36.0;

/// Width of the remove button, or of the gap that takes its place, so
/// durations line up.
const _removeWidth = 40.0;

/// One queued track, drawn as the library's song row ([SongRowView]): drag
/// handle, cover, title, artist, "album • year", length and heart, plus a
/// remove button that shows on hover or focus. Tapping plays it; a right
/// click, long press or the menu key opens its menu.
///
/// Tracks already played are dimmed; the playing one has the playing-song
/// colors, the same while paused. A "play next" row has a bar on its edge.
class QueueTile extends ConsumerWidget {
  const QueueTile({
    super.key,
    required this.track,
    required this.position,
    required this.current,
    required this.played,
    this.upNext = false,
    this.editable = true,
  });

  final Track track;

  /// Play position of this track in the queue.
  final int position;

  /// This is the track playing now.
  final bool current;

  /// This track comes before the playing one.
  final bool played;

  /// This track is in the "play next" block right after the playing one.
  final bool upNext;

  /// `false` for a row shown by the filter: no drag handle and no remove
  /// button, since the rows are not the whole queue. The row menu is kept.
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final player = ref.read(playerServiceProvider.notifier);
    final path = localPathOf(track.uri);
    // The heart adds only songs of the library. While that is still being
    // read it stays off (an added favorite can always be taken out again), so
    // it never offers an add that the press would refuse.
    final canAdd = path != null
        ? (ref.watch(libraryTrackOfPathProvider(path)).value != null)
        : false;

    // The row height is fixed, so its text stops growing at a cap instead of
    // overflowing at the largest font sizes.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: queueTileMaxTextScale,
      child: Opacity(
        opacity: played ? 0.6 : 1,
        child: QueueTileMenuRegion(
          track: track,
          position: position,
          child: Semantics(
            customSemanticsActions: {
              if (editable)
                CustomSemanticsAction(label: l10n.queueRemove): () =>
                    player.removeTrack(position),
            },
            child: HoverRevealAction(
              builder: (context, revealed) => SongRowView(
                title: track.title,
                artist: track.artist,
                detail: joinRowDetails([track.album, rowYear(track.year)]),
                coverPath: track.artUri,
                duration: track.duration,
                playing: current,
                // The playing row's tap does nothing, but it is not null: a
                // row without a handler cannot take focus, and the menu key
                // would not reach it.
                onTap: current ? () {} : () => player.jump(position),
                leading: editable
                    ? _QueueDragHandle(position: position, current: current)
                    : const SizedBox(width: _handleWidth),
                overlay: upNext ? const QueuePlayNextMarker() : null,
                semanticsHint: upNext ? l10n.queuePlayNext : null,
                heart: FavoriteButton(
                  path: path,
                  compact: true,
                  iconSize: 20,
                  color: current ? colors.onPrimaryContainer : null,
                  canAdd: canAdd,
                ),
                trailing: editable
                    ? RevealableAction(
                        revealed: revealed,
                        child: IconButton(
                          icon: const Icon(AppIcons.deleteRounded),
                          iconSize: 20,
                          constraints: const BoxConstraints.tightFor(
                            width: _removeWidth,
                            height: _removeWidth,
                          ),
                          color: current ? colors.onPrimaryContainer : null,
                          tooltip: l10n.queueRemove,
                          onPressed: () => player.removeTrack(position),
                        ),
                      )
                    : const SizedBox(width: _removeWidth),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The drag handle before the cover. A tap on it is swallowed so a stray
/// click does not start playback through the row's `InkWell`.
class _QueueDragHandle extends StatelessWidget {
  const _QueueDragHandle({required this.position, required this.current});

  final int position;
  final bool current;

  @override
  Widget build(BuildContext context) => ReorderableDragStartListener(
    index: position,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      // The long press on the handle is swallowed so it does not open the
      // row's menu.
      onLongPress: () {},
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Tooltip(
          message: context.l10n.queueReorder,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              AppIcons.dragHandle,
              size: 20,
              color: current
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : null,
            ),
          ),
        ),
      ),
    ),
  );
}
