import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'history_providers.dart';
import 'history_range.dart';
import 'history_range_dialog.dart';
import 'most_played_range.dart';

/// Asks for a custom range in the calendar dialog, bounded by the days with
/// plays, and shows the picked days on the Most played page. Does nothing when
/// the dialog was dismissed or nothing was played yet.
Future<void> pickMostPlayedCustom(
  BuildContext context,
  WidgetRef ref,
  DateTime now,
) async {
  final played = ref.read(historyPlayedRangeProvider).value;
  if (played == null) return;
  final current = ref.read(mostPlayedRangeProvider);
  final bounds = pickerBounds(played, now);
  final initial = clampedCustom(current, bounds);
  final picked = await showHistoryRangeDialog(
    context,
    bounds: bounds,
    today: now,
    initial: initial,
  );
  if (picked == null || !context.mounted) return;
  ref
      .read(mostPlayedRangeProvider.notifier)
      .set(
        ref.read(mostPlayedRangeProvider).withCustom(picked.start, picked.end),
      );
}
