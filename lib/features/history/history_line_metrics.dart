import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/song_card.dart';

/// Space between the previous day's last card and a day bar. A song card
/// brings half of [songCardGap] below it, the header line the rest.
const historyDayBarSpaceAbove = 16.0;

/// Space between a day bar and the first card under it (the card brings half
/// of [songCardGap] of it).
const historyDayBarSpaceBelow = 8.0;

/// Sizes of the lines of the timeline. A fixed height per kind of line lets
/// the list place lines, and jump to a day, without measuring.
///
/// Song rows, placeholders and the older-year line are [line] tall (one song
/// card slot). A day's header line is [header] tall: the gap above the bar
/// ([topGap]), the [bar] and the gap below it.
class HistoryLineMetrics {
  const HistoryLineMetrics({
    required this.line,
    required this.bar,
    required this.topGap,
    required this.bottomGap,
  });

  /// Reads the sizes at the theme's and the text scale's song row height.
  factory HistoryLineMetrics.of(ThemeData theme, TextScaler scaler) {
    final line = songCardExtent(theme, scaler);
    final style = theme.textTheme.titleSmall!;
    final text = (scaler.scale(style.fontSize!) * (style.height ?? 1))
        .roundToDouble();
    return HistoryLineMetrics(
      line: line,
      bar: math.min(math.max(48.0, text + 24), line - 8),
      topGap: historyDayBarSpaceAbove - songCardGap / 2,
      bottomGap: historyDayBarSpaceBelow - songCardGap / 2,
    );
  }

  /// Height of a song row line, a placeholder and the older-year line.
  final double line;

  /// Height of the date bar.
  final double bar;

  /// Empty space above the bar in its header line. Hidden on the first day.
  final double topGap;

  /// Empty space under the bar in its header line.
  final double bottomGap;

  /// Height of a day's header line.
  double get header => topGap + bar + bottomGap;
}
