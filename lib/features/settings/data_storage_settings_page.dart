import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'backup_settings_section.dart';
import 'cover_cache_setting_rows.dart';
import 'log_folder_setting_row.dart';
import 'online_lyrics_cache_setting_row.dart';
import 'settings_page_scaffold.dart';
import 'settings_section.dart';
import 'translation_cache_setting_row.dart';

/// Settings › Data & storage: Backup and restore, Caches and Logs.
class DataStorageSettingsPage extends StatelessWidget {
  const DataStorageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SettingsPageScaffold(
      title: l10n.settingsDataStorage,
      children: [
        const BackupSettingsSection(),
        SettingsSection(
          title: l10n.settingsGroupCaches,
          children: const [
            CoverCacheSettingRows(),
            OnlineLyricsCacheSettingRow(),
            TranslationCacheSettingRow(),
          ],
        ),
        SettingsSection(
          title: l10n.settingsGroupLogs,
          children: const [LogFolderSettingRow()],
        ),
      ],
    );
  }
}
