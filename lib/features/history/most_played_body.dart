import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/in_page_no_match.dart';
import '../../shared/widgets/library_loading.dart';
import 'history_screen_states.dart';
import 'most_played_list.dart';

/// What fills the Most played page under its range bar: the failure, the
/// loading state, the empty state, the filter's "no match" or the list.
/// [ranks] are the 0-based positions in [rows] that the filter lets through,
/// best first; the shown rank of a row is its position plus one.
class MostPlayedBody extends StatelessWidget {
  const MostPlayedBody({
    super.key,
    required this.loading,
    required this.failed,
    required this.rows,
    required this.ranks,
    required this.capped,
    required this.query,
  });

  final bool loading;
  final bool failed;
  final List<HistoryTopRow>? rows;
  final List<int> ranks;
  final bool capped;
  final String query;

  @override
  Widget build(BuildContext context) {
    final rows = this.rows;
    if (failed) return const HistoryLoadFailed();
    if (rows == null || (rows.isEmpty && loading)) {
      return const LibraryLoading();
    }
    if (rows.isEmpty) {
      return EmptyState(
        icon: AppIcons.history,
        title: context.l10n.historyTopEmpty,
      );
    }
    if (ranks.isEmpty) {
      return SingleChildScrollView(child: InPageNoMatch(query: query));
    }
    return MostPlayedList(
      rows: [for (final i in ranks) rows[i]],
      ranks: [for (final i in ranks) i + 1],
      capped: capped,
    );
  }
}
