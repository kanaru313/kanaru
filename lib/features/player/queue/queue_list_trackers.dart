import '../../../core/player/play_queue.dart';

/// Play position of each entry of a queue's `order`, built the first time a
/// row needs to be found by its entry and again when the order changes, so a
/// row whose play position moved can be found again in O(1).
class QueueEntryPositions {
  List<int>? _positions;
  List<int>? _builtFor;

  /// Play position of [entry] in [queue], `-1` when it is not in the queue.
  int of(PlayQueue queue, int entry) {
    final order = queue.order;
    if (!identical(_builtFor, order)) {
      final positions = List<int>.filled(queue.original.length, -1);
      for (var p = 0; p < order.length; p++) {
        positions[order[p]] = p;
      }
      _positions = positions;
      _builtFor = order;
    }
    return _positions![entry];
  }
}

/// Remembers the queue a drag started on, to refuse a drop that outlived a
/// change (a shuffle or Previous can keep the row count, so the list alone
/// would not notice).
class QueueDragGuard {
  ({List<int> order, int index, int playNext})? _start;

  /// A drag is pending.
  bool get dragging => _start != null;

  void begin(PlayQueue queue, int playNext) =>
      _start = (order: queue.order, index: queue.index, playNext: playNext);

  /// Forgets the pending drag.
  void clear() => _start = null;

  /// Ends the pending drag and says whether [queue] is still the one it
  /// started on (`true` when no drag was pending).
  bool endsOn(PlayQueue queue, int playNext) {
    final start = _start;
    _start = null;
    if (start == null) return true;
    return identical(start.order, queue.order) &&
        start.index == queue.index &&
        start.playNext == playNext;
  }
}
