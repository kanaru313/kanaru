import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'about_settings_section.dart';
import 'settings_page_scaffold.dart';

/// Settings › About.
class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: context.l10n.settingsAbout,
      children: const [AboutSettingsSection()],
    );
  }
}
