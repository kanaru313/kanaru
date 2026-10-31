import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import 'queue_tile_menu.dart' show openQueueRowMenu;

/// The ⋮ button: opens the same menu as a right click. Enter and Space on it
/// open the menu from the keyboard (focus lands on its first row).
class QueueMoreButton extends ConsumerWidget {
  const QueueMoreButton({
    super.key,
    required this.position,
    required this.current,
  });

  final int position;
  final bool current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open({required bool viaKeyboard}) {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return;
      final at = box.localToGlobal(box.size.center(Offset.zero));
      openQueueRowMenu(
        context,
        ref,
        position: position,
        at: at,
        viaKeyboard: viaKeyboard,
      );
    }

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
        icon: const Icon(AppIcons.more),
        iconSize: 20,
        color: current
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        onPressed: () => open(viaKeyboard: false),
      ),
    );
  }
}
