import 'package:material_ui/material_ui.dart';

/// The `proxyDecorator` of the entry list: the row being dragged gets a
/// shadow and an opaque plate of the row's own size, so it reads over the
/// rows it passes.
Widget Function(Widget, int, Animation<double>) playlistEntryLift(
  BuildContext context,
) {
  final colors = Theme.of(context).colorScheme;
  return (child, index, animation) => Stack(
    children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
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
      child,
    ],
  );
}
