import 'package:material_ui/material_ui.dart';

/// The mark of a "play next" row: a 3 px rounded accent bar on the row's left
/// edge, 4 px short of its top and bottom. It takes no room, so it works at
/// any row width; give it to `SongRowView.overlay`.
class QueuePlayNextMarker extends StatelessWidget {
  const QueuePlayNextMarker({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
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
