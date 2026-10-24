import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/track.dart';
import '../../../shared/in_page_filter.dart';
import '../../../shared/in_page_filter_host.dart';
import '../../../shared/widgets/in_page_search_field.dart';
import 'queue_filter_results.dart';
import 'queue_panel_header.dart';
import 'queue_save_flow.dart';
import 'queue_sheet_host.dart';
import 'queue_tile.dart';
import 'queue_time_left.dart';

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

/// Above the filter boxes of pages, so `Ctrl+F` with the queue open reaches
/// the queue.
const _queueFilterLayer = 10;

class _QueuePanelState extends ConsumerState<QueuePanel>
    with InPageFilterHost<QueuePanel> {
  late final ScrollController _scroll;
  final _filterButtonFocus = FocusNode(debugLabel: 'queue filter button');

  /// The filter lives as long as the panel: closing the sheet drops it.
  final _filter = InPageFilterController();
  final _view = InPageFilterView<Track>(
    (t) => (title: t.title, artist: t.artist, album: null),
  );

  @override
  InPageFilterController get filterController => _filter;

  @override
  int get filterLayer => _queueFilterLayer;

  @override
  bool get filterAvailable =>
      ref.read(playerServiceProvider).queue.order.isNotEmpty;

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
    _filter.dispose();
    _scroll.dispose();
    _filterButtonFocus.dispose();
    super.dispose();
  }

  /// Esc in the box: the focus goes back to the header button.
  void _focusFilterButton() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _filterButtonFocus.requestFocus();
    });
  }

  /// Closes the filter first (the full queue comes back), then scrolls once
  /// its list is built again.
  void _showCurrent() {
    if (_filter.isOpen) {
      _filter.close();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToCurrent();
      });
      return;
    }
    _scrollToCurrent();
  }

  void _scrollToCurrent() {
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
    final hasLibrary = ref.watch(libraryDatabaseProvider) != null;
    // An emptied queue leaves nothing to show: close the sheet it is in.
    ref.listen(playerServiceProvider.select((s) => s.queue.isEmpty), (
      _,
      empty,
    ) {
      if (empty) QueueSheetHost.maybeOf(context)?.close();
    });

    return ListenableBuilder(
      listenable: _filter,
      builder: (context, _) => Column(
        children: [
          QueuePanelHeader(
            summary: const QueueSummaryText(),
            filterOpen: _filter.isOpen,
            onFilter: _filter.isOpen ? _filter.close : _filter.open,
            filterFocus: _filterButtonFocus,
            onSave: hasLibrary ? () => saveQueueAsPlaylist(ref, context) : null,
            onClear: queue.order.length > 1 ? player.clearQueue : null,
            onShowCurrent: _showCurrent,
            onClose: widget.onClose,
          ),
          if (_filter.isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InPageSearchBox(
                  controller: _filter,
                  onEscape: _focusFilterButton,
                ),
              ),
            ),
          Expanded(
            child: _filter.isFiltering
                ? QueueFilterResults(
                    queue: queue,
                    positions: queueFilterPositions(
                      queue,
                      _view,
                      _filter.terms,
                    ),
                    query: _filter.query,
                  )
                : ReorderableListView.builder(
                    scrollController: _scroll,
                    itemExtent: queueTileExtent,
                    buildDefaultDragHandles: false,
                    itemCount: queue.order.length,
                    // `onReorderItem` already gives the final index of the
                    // dropped row.
                    onReorderItem: player.moveTrack,
                    itemBuilder: (context, position) => QueueTile(
                      // The index in the opened queue: stable while rows move,
                      // and never shared by two copies of the same file.
                      key: ValueKey(queue.order[position]),
                      track: queue.trackAt(position),
                      position: position,
                      current: position == queue.index,
                      played: position < queue.index,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
