import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/song_card.dart';

/// The mark of a "play next" row: a 3 px rounded accent bar on the row's left
/// edge, a corner radius short of its top and bottom, clear of the card's
/// rounded corners. It takes no room, so it works at any row width; give it to
/// `SongRowView.overlay`.
class QueuePlayNextMarker extends StatelessWidget {
  const QueuePlayNextMarker({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: songCardRadius),
    child: Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 3,
        height: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiary,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(1.5),
            ),
          ),
        ),
      ),
    ),
  );
}
