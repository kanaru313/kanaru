import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;

import '../../../core/player/play_queue.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/repeat_mode.dart';
import '../../../l10n/l10n.dart';
import 'queue_list_slivers.dart';
import 'queue_row_focus.dart';
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

  /// Play position of each entry of `queue.order`, built the first time a
  /// row needs to be found by its entry and again when the order changes.
  List<int>? _positionOfEntry;
  List<int>? _positionsFor;

  /// Handle on the upcoming list, to cancel a drag the queue outran.
  final _listKey = GlobalKey<SliverReorderableListState>();

  /// The queue a drag started on, to refuse a drop that outlived a change
  /// (a shuffle or Previous can keep the row count, so the list alone would
  /// not notice). `null` when no drag is pending.
  ({List<int> order, int index, int playNext})? _dragStart;

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
    if (_dragStart != null) {
      _dragStart = null;
      _listKey.currentState?.cancelReorder();
    }
    // Rows remount when the queue changes under them (a track change, a
    // move from the row menu): give focus back to the entry that had it.
    _focus.arm();
    SchedulerBinding.instance.addPostFrameCallback((_) => _focus.disarm());
  }

  /// Whether the queue is still the one the pending drag started on.
  bool _dragIsCurrent() {
    final start = _dragStart;
    _dragStart = null;
    if (start == null) return true;
    return identical(start.order, widget.queue.order) &&
        start.index == widget.queue.index &&
        start.playNext == widget.playNext;
  }

  int _positionOf(int entry) {
    final order = widget.queue.order;
    if (!identical(_positionsFor, order)) {
      final positions = List<int>.filled(widget.queue.original.length, -1);
      for (var p = 0; p < order.length; p++) {
        positions[order[p]] = p;
      }
      _positionOfEntry = positions;
      _positionsFor = order;
    }
    return _positionOfEntry![entry];
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
      -min(widget.queue.index, 3) * queueTileExtent,
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
    required bool current,
    required bool played,
    int? dragIndex,
  }) {
    final queue = widget.queue;
    final entry = queue.order[position];
    return QueueRowFocus(
      entry: entry,
      tracker: _focus,
      child: QueueTile(
        track: queue.trackAt(position),
        position: position,
        current: current,
        played: played,
        dragIndex: dragIndex,
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
    final showEarlier = widget.earlierExpanded && sections.played > 0;
    final String? upcomingLabel = sections.hasUpNextHeader
        ? l10n.queueSectionPlayNext(sections.playNext)
        : (sections.upcomingTracks > 0 ? l10n.queueSectionUpNext : null);

    return CustomScrollView(
      controller: widget.controller,
      center: _centerKey,
      slivers: [
        if (showEarlier)
          QueueEarlierSliver(
            playingIndex: sections.index,
            positionOfEntry: _positionOf,
            rowAt: (position) => _row(position, current: false, played: true),
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
                _row(queue.index, current: true, played: false),
            ],
          ),
        ),
        if (upcomingLabel != null)
          SliverToBoxAdapter(child: QueueSectionLabel(text: upcomingLabel)),
        SliverReorderableList(
          key: _listKey,
          itemExtent: queueTileExtent,
          itemCount: sections.upcomingRows,
          proxyDecorator: (child, index, animation) =>
              queueDragProxy(context, child, index, animation),
          onReorderStart: (_) => _dragStart = (
            order: queue.order,
            index: queue.index,
            playNext: widget.playNext,
          ),
          onReorderItem: (from, to) {
            if (!_dragIsCurrent()) return;
            final drop = sections.drop(from, to);
            if (drop == null) return;
            player.moveTrack(drop.from, drop.to, playNext: drop.playNext);
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
                  height: queueTileExtent,
                ),
              );
            }
            return _row(
              position,
              current: false,
              played: false,
              dragIndex: row,
            );
          },
        ),
        if (queue.repeat == RepeatMode.all && queue.order.isNotEmpty)
          const SliverToBoxAdapter(child: QueueRepeatsFromStartRow()),
      ],
    );
  }
}
