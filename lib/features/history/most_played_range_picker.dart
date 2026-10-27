import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'history_providers.dart';
import 'history_range.dart';
import 'history_range_dialog.dart';

/// Asks for a custom range in the calendar dialog, bounded by the days with
/// plays. Returns [current] with the picked days, or null when the dialog was
/// dismissed or nothing was played yet.
Future<HistoryRangeState?> pickMostPlayedCustom(
  BuildContext context,
  WidgetRef ref,
  HistoryRangeState current,
  DateTime now,
) async {
  final played = ref.read(historyPlayedRangeProvider).value;
  if (played == null) return null;
  final bounds = pickerBounds(played, now);
  final initial = clampedCustom(current, bounds);
  final picked = await showHistoryRangeDialog(
    context,
    bounds: bounds,
    today: now,
    initial: initial,
  );
  return picked == null ? null : current.withCustom(picked.start, picked.end);
}
