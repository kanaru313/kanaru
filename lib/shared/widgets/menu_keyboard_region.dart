import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// The keys that open a context menu from the keyboard: the Menu key and
/// Shift+F10, as in GTK and Windows.
const menuKeyboardActivators = [
  SingleActivator(LogicalKeyboardKey.contextMenu),
  SingleActivator(LogicalKeyboardKey.f10, shift: true),
];

/// Opens the context menu of [child] from the keyboard: while focus is
/// inside [child] (its row's ink well, a button in it), the Menu key or
/// Shift+F10 calls [onOpen] with a point on the row (global) to anchor the
/// menu at, the same menu a right click opens there. The menu route closes
/// on Esc and gives focus back to the row.
///
/// Without a focusable widget inside [child] the keys never arrive; without
/// [onOpen], [child] is returned as is.
class MenuKeyboardRegion extends StatelessWidget {
  const MenuKeyboardRegion({super.key, this.onOpen, required this.child});

  final ValueChanged<Offset>? onOpen;
  final Widget child;

  /// Where a menu opened from the keyboard goes: near the start of the row,
  /// in its vertical middle, so it covers the row's first cells the way a
  /// right click there would.
  static Offset anchorOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return Offset.zero;
    return box.localToGlobal(Offset(24, box.size.height / 2));
  }

  @override
  Widget build(BuildContext context) {
    final open = onOpen;
    if (open == null) return child;
    return Builder(
      builder: (context) => CallbackShortcuts(
        bindings: {
          for (final activator in menuKeyboardActivators)
            activator: () => open(anchorOf(context)),
        },
        child: child,
      ),
    );
  }
}
