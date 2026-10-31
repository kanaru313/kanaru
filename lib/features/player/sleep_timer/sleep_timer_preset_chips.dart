import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import 'sleep_timer_draft.dart';
import 'sleep_timer_labels.dart';

/// Quick choices under the slider. A chip only sets the draft; Start starts.
class SleepTimerPresetChips extends StatelessWidget {
  const SleepTimerPresetChips({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final SleepTimerDraft draft;
  final ValueChanged<SleepTimerDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tracks = draft.tab == SleepTimerSetupTab.tracks;
    final presets = tracks ? sleepTimerTrackPresets : sleepTimerMinutePresets;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final preset in presets)
          ChoiceChip(
            label: Text(tracks ? '$preset' : sleepTimerChipLabel(l10n, preset)),
            tooltip: tracks ? null : l10n.sleepTimerMinutes(preset),
            selected: draft.value == preset,
            showCheckmark: false,
            onSelected: (_) => onChanged(draft.withValue(preset)),
          ),
      ],
    );
  }
}
