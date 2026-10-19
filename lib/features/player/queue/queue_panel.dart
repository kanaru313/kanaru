import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../../../l10n/l10n.dart';
import 'queue_tile.dart';

/// The play queue, editable: drag a row by its handle to reorder, remove a
/// row, play one by tapping it. Only the rows on screen are built, so a
/// queue of tens of thousands of tracks stays light. Used in a drawer and,
/// on narrow windows, as a page of its own.
class QueuePanel extends ConsumerStatefulWidget {
  const QueuePanel({super.key});

  @override
  ConsumerState<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends ConsumerState<QueuePanel> {
  late final ScrollController _scroll;

  /// Offset that puts the playing track on the second row, so the track
  /// just played stays in view above it.
  double _currentOffset() {
    final index = ref.read(playerServiceProvider).queue.index;
    return max(0, index - 1) * queueTileExtent;
  }

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(initialScrollOffset: _currentOffset());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _showCurrent() {
    if (!_scroll.hasClients) return;
    final target = min(_currentOffset(), _scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
      return;
    }
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Not the whole player state: the position ticks must not rebuild rows.
    final queue = ref.watch(playerServiceProvider.select((s) => s.queue));
    final player = ref.read(playerServiceProvider.notifier);
    final tracks = queue.tracks;
    // An emptied queue leaves nothing to show: close the drawer it is in.
    ref.listen(playerServiceProvider.select((s) => s.queue.isEmpty), (
      _,
      empty,
    ) {
      if (empty) Scaffold.maybeOf(context)?.closeEndDrawer();
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 12,
            children: [
              Text(l10n.queueTitle, style: theme.textTheme.titleLarge),
              Text(
                l10n.queueTrackCount(tracks.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            scrollController: _scroll,
            itemExtent: queueTileExtent,
            buildDefaultDragHandles: false,
            itemCount: tracks.length,
            // `onReorderItem` already gives the final index of the dropped row.
            onReorderItem: player.moveTrack,
            itemBuilder: (context, position) => QueueTile(
              // The index in the opened queue: stable while rows move, and
              // never shared by two copies of the same file.
              key: ValueKey(queue.order[position]),
              track: tracks[position],
              position: position,
              current: position == queue.index,
              played: position < queue.index,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // The playing track stays, so there is nothing to confirm.
              // Flexible so a narrow panel or a long translation shrinks the
              // labels instead of overflowing.
              Flexible(
                child: TextButton.icon(
                  icon: const Icon(Icons.clear_all_rounded),
                  label: Text(l10n.queueClear, overflow: TextOverflow.ellipsis),
                  onPressed: tracks.length > 1 ? player.clearQueue : null,
                ),
              ),
              Flexible(
                child: TextButton.icon(
                  icon: const Icon(Icons.my_location_rounded),
                  label: Text(
                    l10n.queueShowCurrent,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: _showCurrent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
