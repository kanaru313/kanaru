import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/sleep_timer.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../playback_controls.dart';
import 'sleep_timer_labels.dart';
import 'sleep_timer_menu.dart';

/// Timer button that opens the sleep timer menu. Outlined while the timer is
/// off; filled in the primary colour, with a short label beside it, while it
/// runs. Only this widget watches the timer, so the countdown rebuilds the
/// button and nothing around it.
class SleepTimerButton extends ConsumerStatefulWidget {
  const SleepTimerButton({
    super.key,
    this.showLabel = true,
    this.onMenuChanged,
  });

  /// Whether the label may go beside the icon; the tooltip has it either way.
  final bool showLabel;

  /// Called with `true` when the menu opens and `false` when it closes, also
  /// when the button leaves the tree with the menu open. The menu floats in
  /// the overlay, so a parent that hides itself on inactivity needs this.
  final ValueChanged<bool>? onMenuChanged;

  @override
  ConsumerState<SleepTimerButton> createState() => _SleepTimerButtonState();
}

class _SleepTimerButtonState extends ConsumerState<SleepTimerButton> {
  bool _open = false;

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
    final state = ref.watch(sleepTimerProvider);
    final scheme = Theme.of(context).colorScheme;
    final tooltip = state.active
        ? l10n.sleepTimerActive(sleepTimerStatusText(l10n, state))
        : l10n.sleepTimer;
    final labelColor = state.countingPaused
        ? scheme.primary.withValues(alpha: 0.5)
        : scheme.primary;

    return MenuAnchor(
      onOpen: () => _setOpen(true),
      onClose: () => _setOpen(false),
      menuChildren: sleepTimerMenuItems(context, ref, state),
      builder: (context, controller, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(AppIcons.sleepTimer),
            selectedIcon: const Icon(AppIcons.sleepTimerActive),
            isSelected: state.active,
            color: state.active ? scheme.primary : null,
            iconSize: playerIconSize,
            tooltip: tooltip,
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
          // The tooltip already carries this text for screen readers.
          if (state.active && widget.showLabel)
            Flexible(
              child: ExcludeSemantics(
                child: Text(
                  sleepTimerShortLabel(l10n, state),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: labelColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
