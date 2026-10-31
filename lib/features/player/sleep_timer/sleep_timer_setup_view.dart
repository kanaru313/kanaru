import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/sleep_timer.dart';
import '../../../l10n/l10n.dart';
import 'sleep_timer_dialog_title.dart';
import 'sleep_timer_draft.dart';
import 'sleep_timer_end_of_rows.dart';
import 'sleep_timer_number_picker.dart';
import 'sleep_timer_preset_chips.dart';
import 'sleep_timer_stops_at_hint.dart';

/// The dialog while choosing when to pause: tabs for minutes, tracks and the
/// end of track, album or queue, then Cancel and Start. Start replaces a
/// running timer.
class SleepTimerSetupView extends ConsumerWidget {
  const SleepTimerSetupView({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onShowRunning,
    required this.onClose,
    this.autofocusNumber = false,
  });

  final SleepTimerDraft draft;
  final ValueChanged<SleepTimerDraft> onChanged;

  /// The "Running" chip: back to the view of the running timer.
  final VoidCallback onShowRunning;

  /// Closes the dialog.
  final VoidCallback onClose;

  /// The number field takes the focus as the view opens.
  final bool autofocusNumber;

  void _start(WidgetRef ref) {
    if (!draft.canStart) return;
    draft.startOn(ref.read(sleepTimerProvider.notifier));
    onClose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final running = ref.watch(sleepTimerProvider.select((s) => s.active));
    final hint = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SleepTimerDialogTitle(
          text: l10n.sleepTimerSetupTitle,
          trailing: running
              ? ActionChip(
                  label: Text(l10n.sleepTimerBackToRunning),
                  onPressed: onShowRunning,
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SegmentedButton<SleepTimerSetupTab>(
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            segments: [
              ButtonSegment(
                value: SleepTimerSetupTab.minutes,
                label: Text(l10n.sleepTimerTabMinutes),
              ),
              ButtonSegment(
                value: SleepTimerSetupTab.tracks,
                label: Text(l10n.sleepTimerTabTracks),
              ),
              ButtonSegment(
                value: SleepTimerSetupTab.endOf,
                label: Text(l10n.sleepTimerTabEndOf),
              ),
            ],
            selected: {draft.tab},
            onSelectionChanged: (s) => onChanged(draft.copyWith(tab: s.single)),
          ),
        ),
        if (draft.tab == SleepTimerSetupTab.endOf)
          SleepTimerEndOfRows(
            selected: draft.endKind,
            onChanged: (kind) => onChanged(draft.copyWith(endKind: kind)),
          )
        else ...[
          SleepTimerNumberPicker(
            draft: draft,
            onChanged: onChanged,
            onSubmit: () => _start(ref),
            autofocus: autofocusNumber,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: DefaultTextStyle.merge(
              style: hint,
              textAlign: TextAlign.center,
              child: draft.tab == SleepTimerSetupTab.minutes
                  ? SleepTimerStopsAtHint(minutes: draft.minutes)
                  : Text(l10n.sleepTimerTracksHint(draft.tracks)),
            ),
          ),
          SleepTimerPresetChips(draft: draft, onChanged: onChanged),
        ],
        const Divider(height: 24),
        Wrap(
          // Wraps in a narrow window instead of overflowing.
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: onClose,
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: draft.canStart ? () => _start(ref) : null,
              child: Text(l10n.sleepTimerStart),
            ),
          ],
        ),
      ],
    );
  }
}
