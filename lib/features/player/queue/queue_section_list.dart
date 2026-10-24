import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;

import '../../../core/player/play_queue.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/repeat_mode.dart';
import '../../../l10n/l10n.dart';
import 'queue_input_kind.dart';
import 'queue_list_slivers.dart';
import 'queue_list_trackers.dart';
import 'queue_now_playing_tile.dart';
import 'queue_row_extent.dart';
import 'queue_row_focus.dart';
import 'queue_swipe_gate.dart';
import 'queue_section_header.dart';
import 'queue_sections.dart';
import 'queue_tile.dart';

/// The editable queue as sections: Earlier (collapsed by default), Now
/// playing, then one reorderable list for Play next and Up next.
///
/// Built on a [CustomScrollView] whose `center` is the Now playing sliver, so
/// scroll offset 0 always puts Now playing (and the Earlier toggle above it)
/// at the top. The earlier rows sit in a sliver before the center and grow
/// upward when expanded, in the same layout pass, without moving what the
/// user looks at. Only the rows on screen are built whatever the queue size.
class QueueSectionList extends ConsumerStatefulWidget {
  const QueueSectionList({
    super.key,
    required this.queue,
    required this.playNext,
    required this.controller,
    required this.earlierExpanded,
    required this.onEarlierExpandedChanged,
  });

  final PlayQueue queue;

  /// Length of the Play next run right after the current track.
  final int playNext;

  /// Scroll controller of the list, owned by the panel so it can scroll to
  /// the current track.
  final ScrollController controller;

  /// Whether the earlier rows are shown. Kept by the panel, so it lives as
  /// long as the panel and not as long as this list.
  final bool earlierExpanded;
  final ValueChanged<bool> onEarlierExpandedChanged;

  @override
  ConsumerState<QueueSectionList> createState() => _QueueSectionListState();
}

class _QueueSectionListState extends ConsumerState<QueueSectionList> {
  final _centerKey = GlobalKey();
  final _focus = QueueRowFocusTracker();

  final _positions = QueueEntryPositions();

  /// Removes swiped rows once the list is quiet.
  /// The provider container, taken once: swipes still pending are run on
  /// dispose, when `ref` can no longer be used.
  late final ProviderContainer _container;

  late final _swipes = QueueSwipeGate(
    remove: _removeEntries,
    tokenOf: () => _container.read(playerServiceProvider).queue.original,
  );

  /// Removes the swiped entries still in the queue they were swiped in, last
  /// position first so the positions still to remove do not shift.
  ///
  /// Entries number the queue's `original` list and are renumbered when the
  /// queue is replaced, so everything is resolved against the live queue: a
  /// swipe whose `original` is no longer the live one is dropped, as is an
  /// entry out of range or one that is now the playing track.
  void _removeEntries(Map<int, Object> swiped) {
    final queue = _container.read(playerServiceProvider).queue;
    final positions = <int>[];
    for (final MapEntry(key: entry, value: original) in swiped.entries) {
      if (!identical(original, queue.original)) continue;
      if (entry < 0 || entry >= queue.original.length) continue;
      final position = _positions.of(queue, entry);
      if (position >= 0 && position != queue.index) positions.add(position);
    }
    positions.sort((a, b) => b.compareTo(a));
    final player = _container.read(playerServiceProvider.notifier);
    for (final position in positions) {
      player.removeTrack(position);
    }
  }

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    _swipes.dispose();
    super.dispose();
  }

  /// Handle on the upcoming list, to cancel a drag the queue outran.
  final _listKey = GlobalKey<SliverReorderableListState>();

  /// Refuses a drop that outlived a queue change.
  final _drag = QueueDragGuard();

  @override
  void didUpdateWidget(QueueSectionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.queue;
    final queue = widget.queue;
    final changed =
        !identical(queue.order, old.order) ||
        queue.index != old.index ||
        widget.playNext != oldWidget.playNext;
    if (!changed) return;
    // The rows are numbered from the playing track and a drop is a pair of
    // row numbers: a drag begun on the old queue means something else now.
    if (_drag.dragging) {
      _drag.clear();
      _listKey.currentState?.cancelReorder();
    }
    // Rows remount when the queue changes under them (a track change, a
    // move from the row menu): give focus back to the entry that had it.
    _focus.arm();
    SchedulerBinding.instance.addPostFrameCallback((_) => _focus.disarm());
  }

  void _toggleEarlier() {
    final controller = widget.controller;
    if (widget.earlierExpanded) {
      // Leave the earlier area before its rows go away.
      if (controller.hasClients && controller.offset < 0) controller.jumpTo(0);
      widget.onEarlierExpandedChanged(false);
      return;
    }
    widget.onEarlierExpandedChanged(true);
    SchedulerBinding.instance.addPostFrameCallback((_) => _revealEarlier());
  }

  /// Slides the newest few earlier rows into view after expanding.
  void _revealEarlier() {
    final controller = widget.controller;
    if (!mounted || !controller.hasClients) return;
    final position = controller.position;
    final target = max(
      -min(widget.queue.index, 3) * queueRowExtent(context),
      position.minScrollExtent,
    );
    if (position.pixels <= target) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpTo(target);
      return;
    }
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutQuart,
    );
  }

  /// A row of the queue, remembered for focus across track changes.
  Widget _row(
    int position, {
    bool current = false,
    bool played = false,
    int? dragIndex,
  }) {
    final queue = widget.queue;
    final entry = queue.order[position];
    return QueueRowFocus(
      entry: entry,
      tracker: _focus,
      child: current
          ? QueueNowPlayingTile(
              track: queue.trackAt(position),
              position: position,
            )
          : QueueTile(
              track: queue.trackAt(position),
              position: position,
              current: false,
              played: played,
              dragIndex: dragIndex,
              swipeGate: _swipes,
              entry: entry,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = widget.queue;
    final sections = QueueSections(
      index: queue.index,
      playNext: widget.playNext,
      length: queue.order.length,
    );
    final l10n = context.l10n;
    final player = ref.read(playerServiceProvider.notifier);
    final extent = queueRowExtent(context);
    final showEarlier = widget.earlierExpanded && sections.played > 0;
    final String? upcomingLabel = sections.hasUpNextHeader
        ? l10n.queueSectionPlayNext(sections.playNext)
        : (sections.upcomingTracks > 0 ? l10n.queueSectionUpNext : null);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _swipes.pointerDown(),
      onPointerUp: (_) => _swipes.pointerUp(),
      onPointerCancel: (_) => _swipes.pointerUp(),
      child: QueueInputScope(
        child: Builder(
          builder: (context) {
            // Read under the scope and handed to the lifted row, which is drawn
            // in the overlay, outside it.
            final touch = QueueInputScope.touchOf(context);
            return CustomScrollView(
              controller: widget.controller,
              center: _centerKey,
              slivers: [
                if (showEarlier)
                  QueueEarlierSliver(
                    playingIndex: sections.index,
                    rowExtent: extent,
                    positionOfEntry: (entry) => _positions.of(queue, entry),
                    rowAt: (position) => _row(position, played: true),
                  ),
                SliverToBoxAdapter(
                  key: _centerKey,
                  child: Column(
                    children: [
                      if (sections.played > 0)
                        QueueEarlierToggle(
                          count: sections.played,
                          expanded: widget.earlierExpanded,
                          onToggle: _toggleEarlier,
                        ),
                      if (queue.order.isNotEmpty)
                        _row(queue.index, current: true),
                    ],
                  ),
                ),
                if (upcomingLabel != null)
                  SliverToBoxAdapter(
                    child: QueueSectionLabel(text: upcomingLabel),
                  ),
                SliverReorderableList(
                  key: _listKey,
                  itemExtent: extent,
                  itemCount: sections.upcomingRows,
                  proxyDecorator: (child, index, animation) => QueueInputValue(
                    touch: touch,
                    child: queueDragProxy(context, child, index, animation),
                  ),
                  onReorderStart: (_) => _drag.begin(queue, widget.playNext),
                  onReorderItem: (from, to) {
                    if (!_drag.endsOn(queue, widget.playNext)) return;
                    final drop = sections.drop(from, to);
                    if (drop == null) return;
                    player.moveTrack(
                      drop.from,
                      drop.to,
                      playNext: drop.playNext,
                    );
                  },
                  itemBuilder: (context, row) {
                    final position = sections.positionOfRow(row);
                    if (position == null) {
                      // The "Up next" header: a row so a drag across it moves a track
                      // into or out of Play next. The list still advertises its move
                      // actions on this row (it cannot be turned off); `drop` returns
                      // null for it, so using one does nothing.
                      return KeyedSubtree(
                        key: const ValueKey('queue-up-next-header'),
                        child: QueueSectionLabel(
                          text: l10n.queueSectionUpNext,
                          height: extent,
                        ),
                      );
                    }
                    return _row(position, dragIndex: row);
                  },
                ),
                if (queue.repeat == RepeatMode.all && queue.order.isNotEmpty)
                  const SliverToBoxAdapter(child: QueueRepeatsFromStartRow()),
              ],
            );
          },
        ),
      ),
    );
  }
}
