import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_identity.dart';
import '../../core/lyrics/plugins/plugin_log_paths.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/show_in_file_manager.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'plugin_open_url.dart';

/// Address of the guide for people who write plugins.
const lyricsPluginGuideUrl =
    '$kanaruRepositoryUrl/blob/main/docs/lyrics-plugin-api.md';

enum _Choice { logFolder, guide }

/// The menu at the top right of the sources page: open the folder of the
/// plugin log files, open the plugin writing guide.
class LyricsSourcesMenu extends ConsumerWidget {
  const LyricsSourcesMenu({super.key});

  Future<void> _openLogFolder(BuildContext context, WidgetRef ref) async {
    // Taken before the awaits: leaving the page meanwhile must not throw.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final dir = ref.read(lyricsPluginLogDirProvider);
    if (dir == null) {
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.settingsLogFolderUnavailable,
        ),
      );
      return;
    }
    try {
      // No plugin has logged yet: the folder does not exist, and the file
      // manager cannot show what is not there.
      Directory(dir.path).createSync(recursive: true);
    } on FileSystemException {
      // Opening below fails the same way and reports it.
    }
    if (await ref.read(showInFileManagerProvider)(dir.path)) return;
    messenger.showSnackBar(
      appSnackBar(
        kind: AppSnackBarKind.error,
        title: l10n.settingsOpenFailed(dir.path),
      ),
    );
  }

  Future<void> _openGuide(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.settingsOpenFailed(lyricsPluginGuideUrl);
    if (await ref.read(lyricsSourcesOpenUrlProvider)(lyricsPluginGuideUrl)) {
      return;
    }
    messenger.showSnackBar(
      appSnackBar(kind: AppSnackBarKind.error, title: failed),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<_Choice>(
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      icon: const Icon(AppIcons.more),
      onSelected: (choice) => switch (choice) {
        _Choice.logFolder => _openLogFolder(context, ref),
        _Choice.guide => _openGuide(context, ref),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _Choice.logFolder,
          child: ListTile(
            leading: const Icon(AppIcons.folderOpen),
            title: Text(l10n.lyricsSourcesMenuLogFolder),
          ),
        ),
        PopupMenuItem(
          value: _Choice.guide,
          child: ListTile(
            leading: const Icon(AppIcons.openExternal),
            title: Text(l10n.lyricsSourcesMenuGuide),
          ),
        ),
      ],
    );
  }
}
