import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'search_query_label.dart';

/// The line above the results saying they are for [query], the typed words
/// with their typos fixed.
class SearchCorrectedBanner extends StatelessWidget {
  const SearchCorrectedBanner({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text(context.l10n.searchCorrectedResultsForPrefix, style: textStyle),
          SearchQueryLabel(query: query),
        ],
      ),
    );
  }
}
