import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/indexer/folder_watcher_provider.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'setting_row.dart';

/// "Watch music folders": rescans by itself when files change. Off without a
/// library database. When the system ran out of inotify watches the switch
/// keeps its value (the setting is the user's), and the subtitle says why
/// nothing is watched.
class FolderWatchRow extends ConsumerWidget {
  const FolderWatchRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scan = ref.watch(settingsProvider.select((s) => s.libraryScan));
    final limited =
        ref.watch(folderWatcherProvider) == WatchStatus.limitReached;
    return SettingRow.single(
      title: l10n.settingsWatchFolders,
      subtitle: limited
          ? l10n.settingsWatchFoldersLimit
          : l10n.settingsWatchFoldersHint,
      control: Switch(
        value: scan.watchFolders,
        onChanged: ref.watch(libraryDatabaseProvider) != null
            ? (value) => ref
                  .read(settingsProvider.notifier)
                  .setLibraryScan(scan.copyWith(watchFolders: value))
            : null,
      ),
    );
  }
}
