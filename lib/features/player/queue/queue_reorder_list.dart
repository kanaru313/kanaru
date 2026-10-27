import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/play_queue.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/track.dart';
import '../../../shared/widgets/song_card_lift.dart';
import 'queue_locate_button.dart';
import 'queue_tile.dart';

/// The whole queue as a list the rows of which can be dragged by their
/// handle. Only the rows on screen are built, and all rows have the height
/// [extent], so a queue of tens of thousands of tracks stays light.
class QueueReorderList extends ConsumerStatefulWidget {
  const QueueReorderList({
    super.key,
    required this.queue,
    required this.upNextRun,
    required this.extent,
    required this.scrollController,
    required this.onShowCurrent,
  });

  final PlayQueue queue;

  /// How many rows after the playing one are "play next" rows.
  final int upNextRun;
  final double extent;
  final ScrollController scrollController;

  /// Scrolls back to the playing row; the floating button calls it.
  final VoidCallback onShowCurrent;

  @override
  ConsumerState<QueueReorderList> createState() => _QueueReorderListState();
}

class _QueueReorderListState extends ConsumerState<QueueReorderList> {
  /// Entry and track of the row being dragged, to find it again at the drop
  /// even if the queue changed meanwhile.
  int? _dragEntry;
  Track? _dragTrack;

  /// True while a row is held; hides the floating button.
  final _dragging = ValueNotifier<bool>(false);

  /// Bumped when the scroll metrics change (viewport resized, list attached
  /// again after the filter closes), so the floating button rechecks.
  final _metrics = _MetricsNotifier();

  @override
  void dispose() {
    _dragging.dispose();
    _metrics.dispose();
    super.dispose();
  }

  void _onReorderStart(int index) {
    final queue = ref.read(playerServiceProvider).queue;
    if (index < 0 || index >= queue.order.length) return;
    _dragging.value = true;
    _dragEntry = queue.order[index];
    _dragTrack = queue.original[_dragEntry!];
  }

  /// Moves the dragged row to [to]. The row is found again by its entry: the
  /// queue may have advanced (a shuffle can reorder it) or been replaced
  /// while the row was held, and the index the list reports is then stale.
  /// Entry numbers are reused by a new queue, so the track must be the same
  /// object too; otherwise the drop is ignored.
  void _onReorder(int from, int to) {
    final entry = _dragEntry;
    final track = _dragTrack;
    _dragEntry = null;
    _dragTrack = null;
    if (entry == null || track == null) return;
    final queue = ref.read(playerServiceProvider).queue;
    if (entry >= queue.original.length ||
        !identical(queue.original[entry], track)) {
      return;
    }
    final now = queue.order.indexOf(entry);
    if (now < 0) return;
    ref.read(playerServiceProvider.notifier).moveTrack(now, to);
  }

  @override
  Widget build(BuildContext context) {
    final queue = widget.queue;
    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            _metrics.notify();
            return false;
          },
          child: _list(queue),
        ),
        PositionedDirectional(
          end: 16,
          bottom: 16,
          child: QueueLocateButton(
            controller: widget.scrollController,
            extent: widget.extent,
            currentIndex: queue.index,
            itemCount: queue.order.length,
            relayout: _metrics,
            dragging: _dragging,
            onPressed: widget.onShowCurrent,
          ),
        ),
      ],
    );
  }

  Widget _list(PlayQueue queue) {
    return ReorderableListView.builder(
      scrollController: widget.scrollController,
      itemExtent: widget.extent,
      // Room under the last row for the floating button. Constant, so the
      // offsets never jump when the button comes and goes.
      padding: const EdgeInsets.only(bottom: queueLocateClearance),
      buildDefaultDragHandles: false,
      itemCount: queue.order.length,
      onReorderStart: _onReorderStart,
      onReorderEnd: (_) => _dragging.value = false,
      // `to` is already the final index of the dropped row.
      onReorderItem: _onReorder,
      proxyDecorator: songCardLift(context),
      itemBuilder: (context, position) => QueueTile(
        // The index in the opened queue: stable while rows move, and never
        // shared by two copies of the same file.
        key: ValueKey(queue.order[position]),
        track: queue.trackAt(position),
        position: position,
        current: position == queue.index,
        played: position < queue.index,
        upNext: isUpNextRow(queue, position, widget.upNextRun),
      ),
    );
  }
}

/// A [ChangeNotifier] that anyone in the file may fire.
class _MetricsNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
