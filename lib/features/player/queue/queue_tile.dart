import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../../../core/player/track.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../track_artwork.dart';
import 'queue_input_kind.dart';
import 'queue_playing_indicator.dart';
import 'queue_row_actions.dart';
import 'queue_row_text.dart';
import 'queue_swipe_gate.dart';
import 'queue_tile_menu.dart';

/// Side of the cover of a queue row.
const queueCoverSize = 40.0;

/// One queued track as a flat row: cover, title and artist, length, and on
/// hover or keyboard focus a remove button and a drag handle. Tapping plays
/// it; a right click, long press or the menu key opens its menu (the heart,
/// the Play next moves and remove). With a finger a row also swipes away from
/// the end to remove it; a mouse or trackpad never removes by dragging.
///
/// Tracks before the playing one have their text dimmed (by color, not by
/// opacity, so a row does not need a layer of its own).
class QueueTile extends ConsumerStatefulWidget {
  const QueueTile({
    super.key,
    required this.track,
    required this.position,
    required this.current,
    required this.played,
    this.editable = true,
    this.dragIndex,
    this.swipeGate,
    this.entry = -1,
  });

  final Track track;

  /// Play position of this track in the queue.
  final int position;

  /// This is the track playing now (only a filtered list shows it as a
  /// plain row; the queue itself uses the Now playing row).
  final bool current;

  /// This track comes before the playing one.
  final bool played;

  /// `false` for a row shown by the filter: no drag handle, no remove button
  /// and no swipe, since the rows are not the whole queue. The row menu is
  /// kept.
  final bool editable;

  /// Index of this row in the reorderable list it sits in, which is what the
  /// drag handle needs (it is not the play position: the list holds only the
  /// upcoming rows). `null` for a row that cannot be dragged, like the
  /// earlier ones; those keep an empty slot where the handle would be.
  final int? dragIndex;

  /// Defers the removal of a swiped row until the list is quiet. Without
  /// one, a swiped row is removed at once.
  final QueueSwipeGate? swipeGate;

  /// The queue entry this row shows, which the [swipeGate] removes by.
  final int entry;

  @override
  ConsumerState<QueueTile> createState() => _QueueTileState();
}

class _QueueTileState extends ConsumerState<QueueTile> {
  /// Kind of the pointer that last went down on the row. A swipe only
  /// removes when it came from a finger or a stylus. A trackpad pan is not
  /// a pointer-down, so it is recorded on its own start.
  PointerDeviceKind _lastDownKind = PointerDeviceKind.mouse;

  /// The swipe finished and the row is leaving the queue: its slot stays
  /// empty until the list drops it (a finished `Dismissible` must not be
  /// built again).
  /// The queue as it was when the pointer went down, to tell a swipe of a
  /// queue that has since been replaced.
  Object? _swipeToken;

  late var _dismissed = widget.swipeGate?.isPending(widget.entry) ?? false;

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    final player = ref.read(playerServiceProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final row = QueueRowReveal(
      builder: (context, revealed) => _row(context, revealed, player),
    );
    if (!widget.editable) return row;
    if (_dismissed) return const SizedBox.shrink();
    return Listener(
      onPointerDown: (event) {
        _lastDownKind = event.kind;
        _swipeToken = widget.swipeGate?.tokenOf();
      },
      // A trackpad pan has no pointer-down: note it here so an earlier touch
      // does not let a pan with the trackpad remove the row.
      onPointerPanZoomStart: (event) =>
          _lastDownKind = PointerDeviceKind.trackpad,
      // The same subtree whatever the input: only the answer to "may this
      // swipe remove?" depends on the pointer, so nothing is rebuilt under
      // a gesture in progress.
      child: Dismissible(
        key: const ValueKey('queue-row-swipe'),
        direction: DismissDirection.endToStart,
        // The row leaves the moment the swipe ends: a pause to shrink it
        // would let a queue change remount the row and lose the swipe (rows
        // have a fixed height anyway).
        resizeDuration: null,
        confirmDismiss: (_) async => queueSwipeRemoves(_lastDownKind),
        onDismissed: (_) {
          setState(() => _dismissed = true);
          final gate = widget.swipeGate;
          if (gate == null) {
            player.removeTrack(widget.position);
          } else {
            gate.swiped(widget.entry, _swipeToken ?? gate.tokenOf());
          }
        },
        background: ColoredBox(
          color: colors.errorContainer,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Icon(
                AppIcons.deleteRounded,
                color: colors.onErrorContainer,
              ),
            ),
          ),
        ),
        child: row,
      ),
    );
  }

  Widget _row(BuildContext context, bool revealed, PlayerService player) {
    final widget = this.widget;
    final track = widget.track;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final titleColor = widget.current
        ? colors.primary
        : (widget.played ? colors.onSurfaceVariant : null);
    final artistColor = widget.current
        ? colors.primary
        : colors.onSurfaceVariant.withValues(alpha: widget.played ? 0.8 : 1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: QueueTileMenuRegion(
        track: track,
        position: widget.position,
        child: Material(
          type: MaterialType.transparency,
          child: Semantics(
            // Remove as an action of the row, for screen readers: the button
            // itself is hidden (and its actions blocked) until the row is
            // hovered or focused.
            customSemanticsActions: {
              if (widget.editable)
                CustomSemanticsAction(label: context.l10n.queueRemove): () =>
                    player.removeTrack(widget.position),
            },
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              // The playing row does nothing: tapping it must not restart the
              // track.
              onTap: widget.current ? null : () => player.jump(widget.position),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    TrackArtwork(
                      artUri: track.artUri,
                      size: queueCoverSize,
                      radius: 6,
                    ),
                    const SizedBox(width: 12),
                    QueueRowText(
                      track: track,
                      titleColor: titleColor,
                      artistColor: artistColor,
                    ),
                    if (widget.current) const QueuePlayingIndicator(),
                    QueueRowDuration(track: track),
                    if (widget.editable)
                      QueueRowActions(
                        revealed: revealed,
                        onRemove: () => player.removeTrack(widget.position),
                        dragIndex: widget.dragIndex,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
