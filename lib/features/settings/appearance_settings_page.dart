import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'appearance_layout_setting_rows.dart';
import 'appearance_text_setting_rows.dart';
import 'appearance_theme_setting_rows.dart';
import 'interface_setting_rows.dart';
import 'settings_page_scaffold.dart';
import 'settings_section.dart';

/// Settings › Appearance: Theme, Text and Layout.
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SettingsPageScaffold(
      title: l10n.settingsAppearance,
      children: [
        SettingsSection(
          title: l10n.settingsGroupTheme,
          children: const [AppearanceThemeSettingRows()],
        ),
        SettingsSection(
          title: l10n.settingsGroupText,
          children: const [AppearanceTextSettingRows()],
        ),
        SettingsSection(
          title: l10n.settingsGroupLayout,
          children: const [
            InterfaceSettingRows(),
            AppearanceLayoutSettingRows(),
          ],
        ),
      ],
    );
  }
}
