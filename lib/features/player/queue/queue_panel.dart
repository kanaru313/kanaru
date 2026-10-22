import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/player/player_service.dart';
import 'queue_panel_header.dart';
import 'queue_save_flow.dart';
import 'queue_sheet_host.dart';
import 'queue_tile.dart';

/// The play queue, editable: drag a row by its handle to reorder, remove a
/// row, play one by tapping it. Only the rows on screen are built, so a
/// queue of tens of thousands of tracks stays light. Used in the side sheet
/// and, on narrow windows, as a page of its own.
class QueuePanel extends ConsumerStatefulWidget {
  const QueuePanel({super.key, this.onClose});

  /// Shows a close button in the header; `null` on the narrow page.
  final VoidCallback? onClose;

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
    // Not the whole player state: the position ticks must not rebuild rows.
    final queue = ref.watch(playerServiceProvider.select((s) => s.queue));
    final player = ref.read(playerServiceProvider.notifier);
    final tracks = queue.tracks;
    // An emptied queue leaves nothing to show: close the sheet it is in.
    ref.listen(playerServiceProvider.select((s) => s.queue.isEmpty), (
      _,
      empty,
    ) {
      if (empty) QueueSheetHost.maybeOf(context)?.close();
    });

    return Column(
      children: [
        QueuePanelHeader(
          trackCount: tracks.length,
          onSave: ref.watch(libraryDatabaseProvider) == null
              ? null
              : () => saveQueueAsPlaylist(ref, context),
          onClear: tracks.length > 1 ? player.clearQueue : null,
          onShowCurrent: _showCurrent,
          onClose: widget.onClose,
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
      ],
    );
  }
}
