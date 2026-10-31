import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import 'sleep_timer_draft.dart';
import 'sleep_timer_number_field.dart';

/// The number part of the Minutes and Tracks tabs: the big editable number
/// between the - and + buttons, its unit, and the tick slider. The hint and
/// the chips go below it, in the setup view.
class SleepTimerNumberPicker extends StatelessWidget {
  const SleepTimerNumberPicker({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onSubmit,
    this.autofocus = false,
  });

  final SleepTimerDraft draft;
  final ValueChanged<SleepTimerDraft> onChanged;

  /// Enter in the field or on the slider.
  final VoidCallback onSubmit;

  /// Whether the field takes the focus when it appears: only when the
  /// dialog opens, not when a keyboard user picks a tab.
  final bool autofocus;

  bool get _tracks => draft.tab == SleepTimerSetupTab.tracks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final unit = _tracks
        ? l10n.sleepTimerUnitTracks(draft.value)
        : l10n.sleepTimerUnitMinutes;
    final range = draft.sliderMax - draft.sliderMin;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          // Scales down in a narrow window instead of overflowing.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.outlined(
                  icon: const Icon(Icons.remove),
                  tooltip: _tracks
                      ? l10n.sleepTimerRemoveTrack
                      : l10n.sleepTimerSubtract,
                  onPressed: draft.canStepDown
                      ? () => onChanged(draft.stepped(-1))
                      : null,
                ),
                const SizedBox(width: 18),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SleepTimerNumberField(
                      // A tab has its own range: start the field afresh.
                      key: ValueKey(draft.tab),
                      value: draft.value,
                      max: draft.max,
                      autofocus: autofocus,
                      semanticsLabel: _tracks
                          ? l10n.sleepTimerTracksFieldLabel
                          : l10n.sleepTimerTabMinutes,
                      onChanged: (n) => onChanged(draft.withTyped(n)),
                      onSubmit: onSubmit,
                    ),
                    const SizedBox(height: 2),
                    ExcludeSemantics(
                      child: Text(
                        unit,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                IconButton.outlined(
                  icon: const Icon(Icons.add),
                  tooltip: _tracks
                      ? l10n.sleepTimerAddTrack
                      : l10n.sleepTimerAdd,
                  onPressed: draft.canStepUp
                      ? () => onChanged(draft.stepped(1))
                      : null,
                ),
              ],
            ),
          ),
        ),
        // Enter on the slider starts, like in the field.
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
              onSubmit();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Slider(
            // The 2024 slider: a bar thumb and tick marks, as designed.
            // ignore: deprecated_member_use
            year2023: false,
            value: draft.sliderValue,
            min: draft.sliderMin,
            max: draft.sliderMax,
            divisions: (range / draft.step).round(),
            semanticFormatterCallback: (v) => _tracks
                ? '${v.round()} ${l10n.sleepTimerUnitTracks(v.round())}'
                : '${v.round()} ${l10n.sleepTimerUnitMinutes}',
            onChanged: (v) => onChanged(draft.withValue(v.round())),
          ),
        ),
      ],
    );
  }
}
