import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/home_windows.dart';
import '../../l10n/l10n.dart';
import 'home_providers.dart';

/// The "recently added" windows, one chip each; the one in effect is on.
/// Copied from HistoryYearChips in history_year_chips.dart.
class HomeAddedWindowChips extends ConsumerWidget {
  const HomeAddedWindowChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(homeEffectiveAddedWindowProvider).value;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Row(
        children: [
          for (final window in HomeAddedWindow.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  window.days == null
                      ? l10n.homeAddedWindowAll
                      : l10n.homeAddedWindowDays(window.days!),
                ),
                selected: window == selected,
                onSelected: (_) => ref
                    .read(homeAddedWindowChoiceProvider.notifier)
                    .select(window),
              ),
            ),
        ],
      ),
    );
  }
}
