import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_scaffold.dart';

/// The History page: the songs played so far. A placeholder until play
/// history is listed.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: l10n.navHistory,
      body: EmptyState(
        icon: AppIcons.history,
        title: l10n.navHistory,
        message: l10n.recentlyPlayedEmptyMessage,
      ),
    );
  }
}
