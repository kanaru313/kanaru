import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import 'context_menu_region.dart';

/// The ⋮ button at the end of an item row: calls [onOpen] to open the item's
/// context menu or modal, anchored at the button's bottom-left so a popup
/// opens below it. Always visible, so the menu is reachable without a right
/// click or a long press.
class ContextMenuMoreButton extends StatelessWidget {
  const ContextMenuMoreButton({
    super.key,
    required this.onOpen,
    this.color,
    this.icon = AppIcons.more,
  });

  final ContextMenuOpen onOpen;

  /// Icon color; null keeps the theme's.
  final Color? color;

  /// The glyph: vertical dots by default, horizontal ones for a day bar.
  final IconData icon;

  /// The button's bottom-left in global coordinates, or null while it is not
  /// laid out.
  static Offset? _anchorOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset(0, box.size.height));
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        void open({required bool viaKeyboard}) {
          final at = _anchorOf(context);
          if (at != null) onOpen(viaKeyboard: viaKeyboard, at: at);
        }

        // Enter and Space on the focused button open the menu from the
        // keyboard (focus lands on its first row); a click does not.
        return CallbackShortcuts(
          bindings: {
            for (final key in const [
              LogicalKeyboardKey.enter,
              LogicalKeyboardKey.numpadEnter,
              LogicalKeyboardKey.space,
            ])
              SingleActivator(key): () => open(viaKeyboard: true),
          },
          child: IconButton(
            tooltip: context.l10n.songModalMoreOptions,
            icon: Icon(icon),
            iconSize: 20,
            color: color,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            onPressed: () => open(viaKeyboard: false),
          ),
        );
      },
    );
  }
}
