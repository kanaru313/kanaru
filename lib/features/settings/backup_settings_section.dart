import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'settings_section.dart';

/// Placeholder for backup and restore (SET-03): there is no backend yet, so
/// the row is disabled and says so.
class BackupSettingsSection extends StatelessWidget {
  const BackupSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SettingsSection(
      title: l10n.settingsBackupRestore,
      children: [
        ListTile(
          enabled: false,
          title: Text(l10n.settingsBackupRestore),
          subtitle: Text(l10n.settingsBackupRestoreHint),
        ),
      ],
    );
  }
}
