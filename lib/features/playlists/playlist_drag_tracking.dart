import 'dart:async';

import 'package:flutter/widgets.dart';

import 'playlist_row_cache.dart';
import 'playlist_write_gate.dart';

/// How long after a pointer ends a drag is waited for (see [onPointerEnd]).
const _dragEndGrace = Duration(milliseconds: 600);

/// Bookkeeping of a row drag in a playlist page: which entry the user picked
/// up, and a head that arrived mid-drag and waits for the drag to end.
///
/// The host state owns the row cache and the write gate and hands them in.
mixin PlaylistDragTracking<T extends StatefulWidget> on State<T> {
  /// The row cache the deferred head is reset into.
  PlaylistRowCache get dragCache;

  /// Writes under way: a deferred head is not taken while one runs.
  PlaylistWriteGate get dragWrites;

  /// A row is being dragged, and the entry the user picked up.
  var dragging = false;
  int? dragEntryId;
  int? dragStartIndex;
  Timer? dragTimeout;

  /// The count of a head that arrived during a drag, to reset to when the
  /// drag ends: the rows must not change under the user's hand.
  int? deferredCount;

  void onReorderStart(int index) {
    // The grace timer of an earlier pointer must not end this drag.
    dragTimeout?.cancel();
    dragging = true;
    dragStartIndex = index;
    dragEntryId = dragCache.rowAt(index)?.entryId;
  }

  void onReorderEnd(int index) {
    // The list counts the slot the row is dropped at with the row itself
    // still in it: dropping below where it started gives `start + 1`.
    final start = dragStartIndex;
    final to = start != null && index > start ? index - 1 : index;
    // A drop in another place is followed by `_onReorder`, once the drop
    // animation ends, and the drag counts as running until then: a head that
    // changed the count meanwhile would make the list cancel the drop. A drop
    // where the row started gets no such call: the head is taken now.
    if (to == start) endDrag();
  }

  /// A drag can end without `onReorderEnd` (the pointer was cancelled, or a
  /// second drag took over), and then `dragging` would hold every later
  /// head back for good. A pointer that goes up or is cancelled while a drag
  /// is on gets this long, a drop animation and more, to be followed by the
  /// usual calls; after that the drag is over.
  void onPointerEnd(PointerEvent event) {
    if (!dragging) return;
    dragTimeout?.cancel();
    dragTimeout = Timer(_dragEndGrace, () {
      if (mounted && dragging) endDrag();
    });
  }

  void endDrag() {
    dragging = false;
    dragEntryId = null;
    takeDeferredHead();
  }

  /// Resets the cache to the count of the head that arrived during a drag.
  void takeDeferredHead() {
    final count = deferredCount;
    deferredCount = null;
    if (count != null && !dragWrites.busy) {
      setState(() => dragCache.reset(count));
    }
  }
}
