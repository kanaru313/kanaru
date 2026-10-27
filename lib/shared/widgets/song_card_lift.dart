import 'package:material_ui/material_ui.dart';

import 'song_card.dart';

/// The `proxyDecorator` of a reorderable song list: the row being dragged
/// gets a shadow and an opaque plate shaped like its card (inset like
/// [SongCardFrame]), so it reads over the rows it passes.
Widget Function(Widget, int, Animation<double>) songCardLift(
  BuildContext context,
) {
  final colors = Theme.of(context).colorScheme;
  return (child, index, animation) => Stack(
    children: [
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: songCardInset,
            vertical: songCardGap / 2,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(songCardRadius),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
      ),
      child,
    ],
  );
}
