import 'package:material_ui/material_ui.dart';

/// Gives a scrolling list its own ink layer: hover, focus and splash of a row
/// that scrolls under a header are clipped to the list instead of painting on
/// the nearest outer Material (a dialog, the page).
///
/// Ink is drawn by the nearest [Material] ancestor and clipped to that
/// Material's box, not to the scroll view. This transparent Material sits
/// right around the list, inside a [ClipRect], so its box is the list's box.
class ScrollInkSurface extends StatelessWidget {
  const ScrollInkSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Material(type: MaterialType.transparency, child: child),
  );
}
