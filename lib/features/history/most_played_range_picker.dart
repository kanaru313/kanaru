import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'history_providers.dart';
import 'history_range.dart';

/// Asks for a custom range in the date picker, bounded by the days with
/// plays. Returns [current] with the picked days, or null when the picker was
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
  final picked = await showDateRangePicker(
    context: context,
    currentDate: now,
    firstDate: bounds.first,
    lastDate: bounds.last,
    initialDateRange: initial == null
        ? null
        : DateTimeRange(start: initial.start, end: initial.end),
  );
  return picked == null ? null : current.withCustom(picked.start, picked.end);
}
