import 'package:material_ui/material_ui.dart';

import '../../../core/player/sleep_timer.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/menu_row.dart';

/// The End of tab: Track, Album, Queue as radio rows, none picked at first.
class SleepTimerEndOfRows extends StatelessWidget {
  const SleepTimerEndOfRows({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final SleepTimerMode? selected;
  final ValueChanged<SleepTimerMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final rows = [
      (SleepTimerMode.endOfTrack, l10n.sleepTimerLabelTrack),
      (SleepTimerMode.endOfAlbum, l10n.sleepTimerLabelAlbum),
      (SleepTimerMode.endOfQueue, l10n.sleepTimerLabelQueue),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (mode, label) in rows)
            menuRowSpaced(
              SizedBox(
                width: double.infinity,
                child: RadioMenuButton<SleepTimerMode>(
                  value: mode,
                  groupValue: selected,
                  // The dialog stays: Start is a separate step.
                  closeOnActivate: false,
                  style: menuRowStyle(
                    background: selected == mode
                        ? menuRowSelectedTint(scheme)
                        : null,
                  ),
                  onChanged: (m) {
                    if (m != null) onChanged(m);
                  },
                  child: Text(label),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
