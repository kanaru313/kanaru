import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;

import '../../../core/player/player_service.dart';
import '../../../core/player/repeat_mode.dart';
import '../../../l10n/l10n.dart';
import '../playback_controls.dart';
import 'repeat_labels.dart';
import 'repeat_menu_items.dart';
import 'repeat_mode_icon.dart';

/// The repeat button: opens a menu of repeat modes; its icon and tooltip show
/// the active one. Disabled while the queue is empty, lit unless the queue
/// stops at its end. Only the queue's repeat mode, the counted repeat and the
/// stopped flag are watched, so playback progress does not rebuild it.
class RepeatButton extends ConsumerStatefulWidget {
  const RepeatButton({
    super.key,
    this.iconSize = playerIconSize,
    this.onMenuChanged,
  });

  final double iconSize;

  /// Called with `true` when the menu opens and `false` when it closes, also
  /// when the button leaves the tree with the menu open (see the sleep timer
  /// button: the menu floats in the overlay).
  final ValueChanged<bool>? onMenuChanged;

  @override
  ConsumerState<RepeatButton> createState() => _RepeatButtonState();
}

class _RepeatButtonState extends ConsumerState<RepeatButton> {
  bool _open = false;

  /// Number the counted item arms with while no count runs.
  int _draft = 1;

  void _setOpen(bool open) {
    if (_open == open) return;
    _open = open;
    widget.onMenuChanged?.call(open);
  }

  @override
  void dispose() {
    _setOpen(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (empty, base, times, stopped) = ref.watch(
      playerServiceProvider.select(
        (s) => (s.queue.isEmpty, s.queue.repeat, s.repeatTimes, s.stopped),
      ),
    );
    final counting = isCounting(times);
    final lit = counting || base != RepeatMode.off;

    return MenuAnchor(
      onOpen: () => _setOpen(true),
      onClose: () => _setOpen(false),
      menuChildren: repeatMenuItems(
        context,
        ref,
        base: base,
        times: times,
        stopped: stopped,
        draft: _draft,
        onDraft: (n) => setState(() => _draft = n),
      ),
      builder: (context, controller, _) => IconButton(
        icon: RepeatModeIcon(
          mode: base,
          counted: counting,
          times: times,
          size: widget.iconSize,
        ),
        iconSize: widget.iconSize,
        tooltip: repeatModeLabel(l10n, base, counted: counting, times: times),
        isSelected: lit,
        onPressed: empty
            ? null
            : () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
