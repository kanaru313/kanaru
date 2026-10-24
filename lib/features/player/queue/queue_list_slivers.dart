import 'package:material_ui/material_ui.dart';

import 'queue_tile.dart';

/// The earlier rows, as a sliver that goes before the list's center so it
/// grows upward. Child `i` is the `i`-th track back from the playing one
/// ([playingIndex]), so the newest earlier track is nearest to Now playing.
/// Rows keep their elements when the playing index moves, found again by
/// their entry through [positionOfEntry] (`-1` for an entry not in the
/// queue).
class QueueEarlierSliver extends StatelessWidget {
  const QueueEarlierSliver({
    super.key,
    required this.playingIndex,
    required this.rowAt,
    required this.positionOfEntry,
  });

  final int playingIndex;

  /// Builds the row for a play position.
  final Widget Function(int position) rowAt;
  final int Function(int entry) positionOfEntry;

  @override
  Widget build(BuildContext context) => SliverFixedExtentList(
    itemExtent: queueTileExtent,
    delegate: SliverChildBuilderDelegate(
      (context, i) => rowAt(playingIndex - 1 - i),
      childCount: playingIndex,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<int>) return null;
        final position = positionOfEntry(key.value);
        if (position < 0 || position >= playingIndex) return null;
        return playingIndex - 1 - position;
      },
    ),
  );
}

/// What a row looks like while it is dragged: lifted on an elevated surface.
Widget queueDragProxy(
  BuildContext context,
  Widget child,
  int index,
  Animation<double> animation,
) {
  final colors = Theme.of(context).colorScheme;
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) => Material(
      elevation: 6 * Curves.easeOut.transform(animation.value),
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      child: child,
    ),
    child: child,
  );
}
