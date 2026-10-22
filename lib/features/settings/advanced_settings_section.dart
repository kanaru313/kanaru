import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'listen_history_setting_rows.dart';
import 'log_folder_setting_row.dart';
import 'settings_section.dart';

/// Settings that are rarely changed: listen history, and the rows of the
/// options that need a deeper look.
class AdvancedSettingsSection extends StatelessWidget {
  const AdvancedSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: context.l10n.settingsAdvanced,
      children: const [ListenHistorySettingRows(), LogFolderSettingRow()],
    );
  }
}
