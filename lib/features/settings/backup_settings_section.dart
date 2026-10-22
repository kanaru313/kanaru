import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'setting_row.dart';
import 'settings_section.dart';

/// Placeholder for backup and restore (SET-03): there is no backend yet, so
/// the row is shown as coming soon.
class BackupSettingsSection extends StatelessWidget {
  const BackupSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SettingsSection(
      title: l10n.settingsBackupRestore,
      children: [
        SettingRow.single(
          title: l10n.settingsBackupRestore,
          subtitle: l10n.settingsBackupRestoreHint,
          comingSoon: true,
          control: FilledButton.tonal(
            style: settingButtonStyle(),
            onPressed: null,
            child: Text(
              l10n.settingsBackupExport,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
