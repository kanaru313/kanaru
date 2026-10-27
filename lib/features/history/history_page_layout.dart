import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import 'history_side_pane.dart';
import 'history_two_column_layout.dart';

/// The covers the page tints from, sorted so that the tint changes only when
/// the set of covers does, not each time a play reorders them.
List<String> historyTintKeys(HistoryOverview? overview) =>
    [...?overview?.coverKeys]..sort();

/// The look of the History page, tinted by the latest covers: a side pane
/// beside [column] in a wide window, a header above it in a narrow one (see
/// [HistoryTwoColumnLayout]). Holds no state; [column] (toolbar, year chips,
/// timeline) comes from the screen.
class HistoryPageLayout extends StatelessWidget {
  const HistoryPageLayout({
    super.key,
    required this.overview,
    required this.callbacks,
    required this.column,
  });

  /// Null while the totals are not read (or failed).
  final HistoryOverview? overview;
  final HistoryPageCallbacks callbacks;

  /// The right column; it gets the height left over.
  final Widget column;

  @override
  Widget build(BuildContext context) {
    return HistoryTwoColumnLayout(
      tintKeys: historyTintKeys(overview),
      pane: HistorySidePane(overview: overview, callbacks: callbacks),
      header: HistoryHeader(overview: overview, callbacks: callbacks),
      column: column,
    );
  }
}
