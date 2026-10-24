import 'package:material_ui/material_ui.dart';

import '../../../core/player/play_queue.dart';
import '../../../core/player/track.dart';
import '../../../shared/in_page_filter.dart';
import '../../../shared/widgets/in_page_no_match.dart';
import 'queue_tile.dart';

/// Play positions in [queue] of the tracks that match [terms], best first.
/// The ranking runs over `queue.original`, which keeps its identity when the
/// queue jumps or moves, so [view] folds the words again only when tracks are
/// added; a track that was removed from the queue is dropped. Inside one
/// match tier the tracks follow the play order, not the order they were
/// loaded in.
List<int> queueFilterPositions(
  PlayQueue queue,
  InPageFilterView<Track> view,
  List<String> terms,
) {
  final order = queue.order;
  final positionOf = List<int>.filled(queue.original.length, -1);
  for (var p = 0; p < order.length; p++) {
    positionOf[order[p]] = p;
  }
  return [
    for (final tier in view.tiers(queue.original, terms))
      ...[
        for (final entry in tier)
          if (positionOf[entry] >= 0) positionOf[entry],
      ]..sort(),
  ];
}

/// The rows of the queue that match the filter, best match first. They are
/// the real rows of the queue, so tapping one jumps to it in the queue
/// (nothing is replaced). They have no drag handle or remove button, since
/// they are not the whole queue; the row menu can still remove one.
/// [positions] are play positions in [queue].
class QueueFilterResults extends StatelessWidget {
  const QueueFilterResults({
    super.key,
    required this.queue,
    required this.positions,
    required this.query,
  });

  final PlayQueue queue;
  final List<int> positions;

  /// What was typed, for the message when nothing matches.
  final String query;

  @override
  Widget build(BuildContext context) {
    if (positions.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: InPageNoMatch(query: query),
      );
    }
    return ListView.builder(
      itemExtent: queueTileExtent,
      itemCount: positions.length,
      itemBuilder: (context, i) {
        final position = positions[i];
        return QueueTile(
          key: ValueKey(queue.order[position]),
          track: queue.trackAt(position),
          position: position,
          current: position == queue.index,
          played: position < queue.index,
          editable: false,
        );
      },
    );
  }
}
