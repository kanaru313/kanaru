import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'about_settings_section.dart';
import 'advanced_settings_section.dart';
import 'appearance_settings_section.dart';
import 'backup_settings_section.dart';
import 'library_settings_section.dart';
import 'settings_save_warning.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: context.l10n.navSettings,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Keeps rows readable on wide windows.
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              // Stretched so every section starts at the same left edge,
              // whatever its rows' own width.
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsSaveWarning(),
                  AppearanceSettingsSection(),
                  LibrarySettingsSection(),
                  BackupSettingsSection(),
                  AdvancedSettingsSection(),
                  AboutSettingsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
