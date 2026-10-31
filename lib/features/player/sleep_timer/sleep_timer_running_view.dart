import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/sleep_timer.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/format_duration.dart';
import 'sleep_timer_dialog_title.dart';
import 'sleep_timer_labels.dart';

/// Minutes the add and remove buttons move the countdown by.
const _minutesStep = 5;

/// The dialog while a timer runs: what it waits for, the big value, the
/// controls of its mode, then Turn off and Change.
class SleepTimerRunningView extends ConsumerWidget {
  const SleepTimerRunningView({
    super.key,
    required this.onChange,
    required this.onClose,
  });

  /// Goes to the setup view, filled from the running timer.
  final VoidCallback onChange;

  final VoidCallback onClose;

  /// The big value for [state]: time left, tracks left or the end kind.
  String _bigText(AppLocalizations l10n, SleepTimerState state) =>
      switch (state.mode) {
        SleepTimerMode.minutes => formatDuration(state.remaining),
        SleepTimerMode.tracks => '${state.tracksLeft}',
        _ => sleepTimerShortLabel(l10n, state),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(sleepTimerProvider);
    final timer = ref.read(sleepTimerProvider.notifier);
    final dim = scheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SleepTimerDialogTitle(text: l10n.sleepTimer),
        Text(
          sleepTimerStatusText(l10n, state),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: dim),
        ),
        // The countdown changes every second: the status line above carries
        // it for screen readers, which would otherwise announce each tick.
        ExcludeSemantics(
          child: RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              // Shrinks in a narrow window instead of overflowing.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _bigText(l10n, state),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 76,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: scheme.onSurface.withValues(
                      alpha: state.countingPaused ? 0.55 : 1,
                    ),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            sleepTimerRunningCaption(context, l10n, state),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: dim),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (state.mode == SleepTimerMode.minutes) ...[
              Tooltip(
                message: l10n.sleepTimerAdd,
                child: OutlinedButton(
                  onPressed: () => timer.addMinutes(_minutesStep),
                  child: Text(l10n.sleepTimerAddShort),
                ),
              ),
              Tooltip(
                message: l10n.sleepTimerSubtract,
                child: OutlinedButton(
                  onPressed: state.canSubtract(_minutesStep)
                      ? () => timer.addMinutes(-_minutesStep)
                      : null,
                  child: Text(l10n.sleepTimerSubtractShort),
                ),
              ),
              OutlinedButton(
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
            if (state.mode == SleepTimerMode.tracks) ...[
              Tooltip(
                message: l10n.sleepTimerAddTrack,
                child: OutlinedButton(
                  onPressed: state.canAddTrack
                      ? () => timer.addTracks(1)
                      : null,
                  child: Text(l10n.sleepTimerAddTrackShort),
                ),
              ),
              Tooltip(
                message: l10n.sleepTimerRemoveTrack,
                child: OutlinedButton(
                  onPressed: state.canRemoveTrack
                      ? () => timer.addTracks(-1)
                      : null,
                  child: Text(l10n.sleepTimerRemoveTrackShort),
                ),
              ),
            ],
          ],
        ),
        const Divider(height: 24),
        Wrap(
          // Wraps in a narrow window instead of overflowing.
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error.withValues(alpha: 0.4)),
              ),
              onPressed: () {
                timer.cancel();
                onClose();
              },
              child: Text(l10n.sleepTimerTurnOff),
            ),
            FilledButton(
              onPressed: onChange,
              child: Text(l10n.sleepTimerChange),
            ),
          ],
        ),
      ],
    );
  }
}
