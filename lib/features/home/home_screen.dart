import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_scaffold.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.homeGreetingMorning;
    if (hour < 18) return l10n.homeGreetingAfternoon;
    return l10n.homeGreetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PageScaffold(
      title: _greeting(l10n),
      subtitle: l10n.homeSubtitle,
      body: EmptyState(
        icon: AppIcons.library,
        title: l10n.libraryEmptyTitle,
        message: l10n.libraryEmptyMessage,
      ),
    );
  }
}
