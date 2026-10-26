import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../../../shared/widgets/library_row.dart';
import 'queue_tile.dart';

/// Row height and scroll controller of the queue list, for the state of the
/// panel that holds it. Call [updateListMetrics] from `didChangeDependencies`
/// and [disposeListMetrics] from `dispose`.
///
/// The controller is created on the first call, where the theme and text
/// scale that size the rows can be read (not in `initState`), so the list
/// opens at the playing row in its first frame.
mixin QueueListMetrics<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  ScrollController? _controller;
  double _extent = 0;

  ScrollController get scroll => _controller!;

  /// Height of a row; follows the theme and the (capped) text scale.
  double get extent => _extent;

  /// Offset that puts the playing track on the second row, so the track
  /// just played stays in view above it.
  double currentOffset() {
    final index = ref.read(playerServiceProvider).queue.index;
    return max(0, index - 1) * _extent;
  }

  void updateListMetrics() {
    final next = libraryRowExtent(
      Theme.of(context),
      MediaQuery.textScalerOf(context)
          .clamp(maxScaleFactor: queueTileMaxTextScale),
    );
    if (_controller == null) {
      _extent = next;
      _controller = ScrollController(initialScrollOffset: currentOffset());
      return;
    }
    if (next == _extent) return;
    // Rows changed height: keep the same first row at the top. Corrected
    // before this frame's layout, so no frame shows the old offset.
    final firstRow = (scroll.hasClients ? scroll.offset : 0) / _extent;
    _extent = next;
    if (scroll.hasClients) {
      scroll.position.correctPixels(firstRow.round() * next);
    }
  }

  void disposeListMetrics() => _controller?.dispose();
}
