import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';

/// The ⋮ button at the end of an item row: calls [onOpen] to open the item's
/// context modal. Always visible, so the modal is reachable without a right
/// click or a long press.
class ContextModalMoreButton extends StatelessWidget {
  const ContextModalMoreButton({super.key, required this.onOpen, this.color});

  final void Function({required bool viaKeyboard}) onOpen;

  /// Icon color; null keeps the theme's.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Enter and Space on the focused button open the modal from the keyboard
    // (focus lands on its first row); a click does not.
    return CallbackShortcuts(
      bindings: {
        for (final key in const [
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.numpadEnter,
          LogicalKeyboardKey.space,
        ])
          SingleActivator(key): () => onOpen(viaKeyboard: true),
      },
      child: IconButton(
        tooltip: context.l10n.songModalMoreOptions,
        icon: const Icon(AppIcons.more),
        iconSize: 20,
        color: color,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        onPressed: () => onOpen(viaKeyboard: false),
      ),
    );
  }
}
