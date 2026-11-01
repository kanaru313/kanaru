import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'excluded_folders_list.dart';
import 'folder_watch_row.dart';
import 'library_folders_list.dart';
import 'library_organization_setting_rows.dart';
import 'library_rescan_setting_rows.dart';
import 'library_scan_setting_rows.dart';
import 'library_stats_row.dart';
import 'scan_stats_rows.dart';
import 'settings_page_scaffold.dart';
import 'settings_section.dart';

/// Settings › Library: the counts and what the last scan did (no header),
/// then Folders, Scanning and Organization.
class LibrarySettingsPage extends StatelessWidget {
  const LibrarySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SettingsPageScaffold(
      title: l10n.settingsLibrary,
      children: [
        const SettingsSection(
          title: null,
          children: [LibraryStatsRow(), ScanStatsRows()],
        ),
        SettingsSection(
          title: l10n.settingsGroupFolders,
          children: const [LibraryFoldersList(), ExcludedFoldersList()],
        ),
        SettingsSection(
          title: l10n.settingsGroupScanning,
          children: const [
            LibraryRescanSettingRows(),
            FolderWatchRow(),
            LibraryScanSettingRows(),
          ],
        ),
        SettingsSection(
          title: l10n.settingsGroupOrganization,
          children: const [LibraryOrganizationSettingRows()],
        ),
      ],
    );
  }
}
