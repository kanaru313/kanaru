import 'package:material_ui/material_ui.dart';

import 'menu_keyboard_region.dart';

/// Opens an item's context modal on a right click or a long press of
/// [child], or from the keyboard (Menu key, Shift+F10, see
/// [MenuKeyboardRegion]). [onOpen] does the opening in the gesture handler
/// itself (nothing is awaited first); without it, [child] is returned as is.
class ContextModalRegion extends StatelessWidget {
  const ContextModalRegion({
    super.key,
    required this.onOpen,
    required this.child,
  });

  final void Function({required bool viaKeyboard})? onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final open = onOpen;
    if (open == null) return child;
    return MenuKeyboardRegion(
      onOpen: (_) => open(viaKeyboard: true),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (_) => open(viaKeyboard: false),
        onLongPressStart: (_) => open(viaKeyboard: false),
        child: child,
      ),
    );
  }
}
