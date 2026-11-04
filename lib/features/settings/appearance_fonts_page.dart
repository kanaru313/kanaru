import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'settings_page_scaffold.dart';

class AppearanceFontsPage extends StatelessWidget {
  const AppearanceFontsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsPageScaffold(
      title: l10n.settingsAppearanceFontsTitle,
      actions: [
        IconButton(
          tooltip: l10n.customFontImportTooltip,
          icon: const Icon(AppIcons.add),
          onPressed: () {},
        ),
      ],
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.settingsAppearanceFontsSubtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
