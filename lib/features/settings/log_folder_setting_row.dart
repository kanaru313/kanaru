import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/logging/log_directory.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'open_external.dart';
import 'setting_row.dart';

/// The folder the log files are written to, or null when this system gives
/// none. Swapped out in tests.
final logDirectoryProvider = Provider<String?>(
  (ref) => resolveLogDirectory(Platform.environment),
);

/// A button that opens the log folder in the file manager, to attach logs to
/// a bug report (SET-06). Off, with a note, when there is no log folder.
class LogFolderSettingRow extends ConsumerWidget {
  const LogFolderSettingRow({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, String path) async {
    // Taken before the await: leaving Settings meanwhile must not throw.
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.settingsOpenFailed(path);
    if (await ref.read(openExternalProvider)(path)) return;
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final path = ref.watch(logDirectoryProvider);

    return SettingRow.single(
      title: l10n.settingsOpenLogFolder,
      subtitle: path == null
          ? l10n.settingsLogFolderUnavailable
          : l10n.settingsOpenLogFolderHint,
      control: FilledButton.tonalIcon(
        style: settingButtonStyle(),
        onPressed: path == null ? null : () => _open(context, ref, path),
        icon: const Icon(AppIcons.folderOpen),
        label: Text(
          l10n.settingsOpenLogFolderButton,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
