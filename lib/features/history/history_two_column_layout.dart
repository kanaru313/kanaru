import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/detail_page/cover_tint_page_background.dart';
import '../../shared/widgets/detail_page/detail_side_pane.dart';

/// The split shared by the History and Most played pages, tinted by
/// [tintKeys]: a [pane] beside [column] in a wide window, a [header] above it
/// in a narrow one. The header does not scroll, as the lists of both pages
/// need a fixed line height. Holds no state.
class HistoryTwoColumnLayout extends StatelessWidget {
  const HistoryTwoColumnLayout({
    super.key,
    required this.tintKeys,
    required this.pane,
    required this.header,
    required this.column,
  });

  /// The covers the page tints from; keep them sorted so that the tint
  /// changes only when the set of covers does.
  final List<String> tintKeys;

  /// Left column of a wide window (a `DetailSidePane`).
  final Widget pane;

  /// Strip above [column] in a narrow window.
  final Widget header;

  /// The right column; it gets the height left over.
  final Widget column;

  @override
  Widget build(BuildContext context) {
    return CoverTintPageBackground.blend(
      coverKeys: tintKeys,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < detailSidePaneMinPageWidth) {
            return Column(
              children: [
                header,
                Expanded(child: column),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              pane,
              Expanded(child: column),
            ],
          );
        },
      ),
    );
  }
}
