import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_scaffold.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key, this.query = ''});

  /// Text submitted from the top bar search field.
  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (query.isEmpty) {
      return PageScaffold(
        title: l10n.navSearch,
        body: EmptyState(
          icon: Icons.search,
          title: l10n.searchEmptyTitle,
          message: l10n.searchEmptyMessage,
        ),
      );
    }

    return PageScaffold(
      title: l10n.searchResultsTitle(query),
      body: EmptyState(
        icon: Icons.manage_search,
        title: l10n.libraryEmptyTitle,
        message: l10n.searchNotReadyMessage,
      ),
    );
  }
}
