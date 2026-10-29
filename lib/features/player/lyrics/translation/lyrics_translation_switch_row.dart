import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/l10n.dart';

/// The first row of the translation menu: the "Show translation" switch,
/// with its `T` key hint. [onToggle] flips it; [focusNode] is the menu's
/// place for the focus.
Widget lyricsTranslationSwitchRow(
  BuildContext context, {
  required bool on,
  required VoidCallback onToggle,
  FocusNode? focusNode,
}) {
  final l10n = context.l10n;
  // The focus of an open menu sits on this wrapper, not on the row: a
  // focused row would open the language submenu on the next press of the
  // mouse and close it again at once, which the submenu tests show. The
  // wrapper turns Enter and Space into the row's action.
  return Focus(
    focusNode: focusNode,
    skipTraversal: true,
    onKeyEvent: (_, event) {
      const keys = [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.numpadEnter,
        LogicalKeyboardKey.space,
      ];
      if (event is! KeyDownEvent || !keys.contains(event.logicalKey)) {
        return KeyEventResult.ignored;
      }
      onToggle();
      return KeyEventResult.handled;
    },
    child: MenuItemButton(
      closeOnActivate: false,
      onPressed: onToggle,
      trailingIcon: ExcludeFocus(
        child: Switch(value: on, onChanged: (_) => onToggle()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.lyricsTranslationShow),
          const SizedBox(width: 12),
          Text(
            'T',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
