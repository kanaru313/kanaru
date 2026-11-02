import 'package:material_ui/material_ui.dart';

import 'menu_keyboard_region.dart';

/// Opens a context menu or modal. [viaKeyboard]: the Menu key, Shift+F10, or
/// Enter/Space on a ⋮ button. [at]: the global point to anchor a popup at
/// (the pointer, the row start for a key, the ⋮ button's bottom-left). A
/// modal opener ignores [at].
typedef ContextMenuOpen = void Function({
  required bool viaKeyboard,
  required Offset at,
});

/// Opens the context menu or modal of [child] on a right click or a long
/// press (at the pointer), or from the keyboard (Menu key, Shift+F10, see
/// [MenuKeyboardRegion]; at the row start). [onOpen] does the opening in the
/// gesture handler itself (nothing is awaited first); without it, [child] is
/// returned as is.
class ContextMenuRegion extends StatelessWidget {
  const ContextMenuRegion({
    super.key,
    required this.onOpen,
    required this.child,
  });

  final ContextMenuOpen? onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final open = onOpen;
    if (open == null) return child;
    return MenuKeyboardRegion(
      onOpen: (at) => open(viaKeyboard: true, at: at),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (details) =>
            open(viaKeyboard: false, at: details.globalPosition),
        onLongPressStart: (details) =>
            open(viaKeyboard: false, at: details.globalPosition),
        child: child,
      ),
    );
  }
}
