import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PageScaffold(
      title: l10n.navSettings,
      body: EmptyState(
        icon: Icons.settings_outlined,
        title: l10n.navSettings,
        message: l10n.settingsEmptyMessage,
      ),
    );
  }
}
