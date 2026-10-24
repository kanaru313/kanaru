import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/sleep_timer.dart';
import '../../../l10n/l10n.dart';
import 'sleep_timer_labels.dart';
import 'sleep_timer_minutes_dialog.dart';

/// Minutes offered as presets.
const sleepTimerPresets = [15, 30, 45, 60, 90];

/// Minutes the add and remove items move the countdown by.
const _step = 5;

/// Items of the sleep timer menu. While the timer runs, a header and the
/// controls for it come first; starting again replaces the running timer.
/// [context] is the button's: the custom dialog opens on it.
List<Widget> sleepTimerMenuItems(
  BuildContext context,
  WidgetRef ref,
  SleepTimerState state,
) {
  final l10n = context.l10n;
  final timer = ref.read(sleepTimerProvider.notifier);
  final minutesMode = state.mode == SleepTimerMode.minutes;

  Future<void> askMinutes() async {
    final minutes = await showSleepTimerMinutesDialog(context);
    if (minutes != null) timer.startMinutes(minutes);
  }

  return [
    if (state.active) ...[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Semantics(
          header: true,
          child: Text(
            sleepTimerStatusText(l10n, state),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ),
      if (minutesMode) ...[
        MenuItemButton(
          onPressed: () => timer.addMinutes(_step),
          child: Text(l10n.sleepTimerAdd),
        ),
        MenuItemButton(
          onPressed: state.canSubtract(_step)
              ? () => timer.addMinutes(-_step)
              : null,
          child: Text(l10n.sleepTimerSubtract),
        ),
        MenuItemButton(
          onPressed: state.countingPaused
              ? timer.resumeCounting
              : timer.pauseCounting,
          child: Text(
            state.countingPaused
                ? l10n.sleepTimerResumeCounting
                : l10n.sleepTimerPauseCounting,
          ),
        ),
      ],
      MenuItemButton(
        onPressed: timer.cancel,
        child: Text(l10n.sleepTimerCancel),
      ),
      const Divider(height: 1),
    ],
    for (final minutes in sleepTimerPresets)
      MenuItemButton(
        onPressed: () => timer.startMinutes(minutes),
        child: Text(l10n.sleepTimerMinutes(minutes)),
      ),
    MenuItemButton(onPressed: askMinutes, child: Text(l10n.sleepTimerCustom)),
    const Divider(height: 1),
    MenuItemButton(
      onPressed: timer.startEndOfTrack,
      child: Text(l10n.sleepTimerEndOfTrack),
    ),
    MenuItemButton(
      onPressed: timer.startEndOfAlbum,
      child: Text(l10n.sleepTimerEndOfAlbum),
    ),
    MenuItemButton(
      onPressed: timer.startEndOfQueue,
      child: Text(l10n.sleepTimerEndOfQueue),
    ),
  ];
}
