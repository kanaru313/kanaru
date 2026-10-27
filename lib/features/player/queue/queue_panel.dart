import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/track.dart';
import '../../../shared/in_page_filter.dart';
import '../../../shared/in_page_filter_host.dart';
import 'queue_filter_results.dart';
import 'queue_list_metrics.dart';
import 'queue_panel_header.dart';
import 'queue_save_flow.dart';
import 'queue_sheet_host.dart';
import 'queue_reorder_list.dart';
import 'queue_time_left.dart';

/// The play queue, editable: drag a row by its handle to reorder, remove a
/// row, play one by tapping it. Only the rows on screen are built, so a
/// queue of tens of thousands of tracks stays light. Used in the side sheet
/// and, on narrow windows, as a page of its own.
class QueuePanel extends ConsumerStatefulWidget {
  const QueuePanel({super.key, this.onClose, this.title});

  /// Shows a close button in the header; `null` on the narrow page.
  final VoidCallback? onClose;

  /// Takes the place of the header's title and count, e.g. a tab bar; the
  /// header's buttons stay on its right.
  final Widget? title;

  @override
  ConsumerState<QueuePanel> createState() => _QueuePanelState();
}

/// Above the filter boxes of pages, so `Ctrl+F` with the queue open reaches
/// the queue.
const _queueFilterLayer = 10;

class _QueuePanelState extends ConsumerState<QueuePanel>
    with InPageFilterHost<QueuePanel>, QueueListMetrics<QueuePanel> {
  /// The filter lives as long as the panel: closing the sheet drops it.
  final _filter = InPageFilterController();
  final _view = InPageFilterView<Track>(
    (t) => (title: t.title, artist: t.artist, album: t.album),
  );

  @override
  InPageFilterController get filterController => _filter;

  @override
  int get filterLayer => _queueFilterLayer;

  @override
  bool get filterAvailable =>
      ref.read(playerServiceProvider).queue.order.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateListMetrics();
  }

  @override
  void dispose() {
    _filter.dispose();
    disposeListMetrics();
    super.dispose();
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
    if (!scroll.hasClients) return;
    final target = min(currentOffset(), scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      scroll.jumpTo(target);
      return;
    }
    scroll.animateTo(
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
    final upNextRun = player.upNextRun;
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
            filter: _filter,
            onSave: hasLibrary ? () => saveQueueAsPlaylist(ref, context) : null,
            onClear: queue.order.length > 1 ? player.clearQueue : null,
            onClose: widget.onClose,
            title: widget.title,
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
                    extent: extent,
                    upNextRun: upNextRun,
                  )
                : QueueReorderList(
                    queue: queue,
                    upNextRun: upNextRun,
                    extent: extent,
                    scrollController: scroll,
                    onShowCurrent: _showCurrent,
                  ),
          ),
        ],
      ),
    );
  }
}
