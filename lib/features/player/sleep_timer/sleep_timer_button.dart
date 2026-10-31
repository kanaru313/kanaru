import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/sleep_timer.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../now_playing/now_playing_header_pill.dart';
import '../playback_controls.dart';
import 'sleep_timer_labels.dart';
import 'sleep_timer_dialog.dart';

/// Most room the pill's label takes.
const _pillLabelWidth = 56.0;

/// Timer button that opens the sleep timer dialog. Outlined while the timer
/// is off; filled in the primary colour, with a short label beside it, while
/// it runs. With [pill] the running timer is a pill (the Now Playing
/// header's), like the lyrics buttons. Only this widget watches the timer,
/// so the countdown rebuilds the button and nothing around it.

class SleepTimerButton extends ConsumerStatefulWidget {
  const SleepTimerButton({
    super.key,
    this.showLabel = true,
    this.pill = false,
    this.onDialogChanged,
  });

  /// Whether the label may go beside the icon; the tooltip has it either way.
  final bool showLabel;

  /// Whether a running timer shows as a pill (with [showLabel]) instead of
  /// the icon with a label beside it.
  final bool pill;

  /// Called with `true` when the dialog opens and `false` when it closes,
  /// also when the button leaves the tree with the dialog open. The dialog
  /// covers the window and takes the pointer, so a parent that hides itself
  /// on inactivity must keep itself shown meanwhile.
  final ValueChanged<bool>? onDialogChanged;

  @override
  ConsumerState<SleepTimerButton> createState() => _SleepTimerButtonState();
}

class _SleepTimerButtonState extends ConsumerState<SleepTimerButton> {
  bool _open = false;

  void _setOpen(bool open) {
    if (_open == open) return;
    _open = open;
    widget.onDialogChanged?.call(open);
  }

  Future<void> _openDialog() async {
    if (_open) return;
    _setOpen(true);
    try {
      await showSleepTimerDialog(context);
    } finally {
      // The button may be gone: dispose has reported the close already.
      if (mounted) _setOpen(false);
    }
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

    // The countdown changes the label every second: its own layer keeps
    // that repaint from reaching the rest of the header.
    return RepaintBoundary(
      child: () {
        if (widget.pill && state.active && widget.showLabel) {
          return NowPlayingHeaderPill(
            icon: AppIcons.sleepTimerActive,
            label: sleepTimerShortLabel(l10n, state),
            tooltip: tooltip,
            maxLabelWidth: _pillLabelWidth,
            muted: state.countingPaused,
            tabularFigures: true,
            onPressed: _openDialog,
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(AppIcons.sleepTimer),
              selectedIcon: const Icon(AppIcons.sleepTimerActive),
              isSelected: state.active,
              color: state.active ? scheme.primary : null,
              iconSize: playerIconSize,
              tooltip: tooltip,
              onPressed: _openDialog,
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
        );
      }(),
    );
  }
}
