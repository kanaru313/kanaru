import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/library_row.dart';

/// Height of every line of the timeline (day header lines, song rows,
/// placeholders and the older-year line): one library song row. A fixed
/// height lets the list place lines, and jump to a day, without measuring.
double historyLineExtent(ThemeData theme, TextScaler scaler) =>
    libraryRowExtent(theme, scaler);

/// Height of the date bar that sits at the bottom of a day's header line. The
/// rest of the line (above the bar) is a gap that separates the days.
double historyDayBarHeight(ThemeData theme, TextScaler scaler) {
  final style = theme.textTheme.titleSmall!;
  final text = (scaler.scale(style.fontSize!) * (style.height ?? 1))
      .roundToDouble();
  final bar = math.max(48.0, text + 24);
  return math.min(bar, historyLineExtent(theme, scaler) - 8);
}
