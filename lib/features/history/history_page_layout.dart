import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../shared/widgets/detail_page/cover_tint_page_background.dart';
import '../../shared/widgets/detail_page/detail_side_pane.dart';
import 'history_side_pane.dart';

/// The covers the page tints from, sorted so that the tint changes only when
/// the set of covers does, not each time a play reorders them.
List<String> historyTintKeys(HistoryOverview? overview) =>
    [...?overview?.coverKeys]..sort();

/// The look of the History page, tinted by the latest covers: a side pane
/// beside [column] in a wide window, a header above it in a narrow one. The
/// header does not scroll, as the timeline needs a fixed line height. Holds no
/// state; [column] (toolbar, year chips, timeline) comes from the screen.
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
    return CoverTintPageBackground.blend(
      coverKeys: historyTintKeys(overview),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < detailSidePaneMinPageWidth) {
            return Column(
              children: [
                HistoryHeader(overview: overview, callbacks: callbacks),
                Expanded(child: column),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HistorySidePane(overview: overview, callbacks: callbacks),
              Expanded(child: column),
            ],
          );
        },
      ),
    );
  }
}
