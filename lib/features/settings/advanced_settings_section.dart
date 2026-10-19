import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'app_directories_provider.dart';
import 'open_external.dart';
import 'settings_section.dart';

class AdvancedSettingsSection extends ConsumerWidget {
  const AdvancedSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final paths = ref.watch(appDirectoryPathsProvider);
    final file = ref.watch(settingsFileProvider);

    return SettingsSection(
      title: l10n.settingsAdvanced,
      children: [
        if (file != null && file.readOnly)
          ListTile(
            leading: Icon(
              Icons.warning_amber_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(l10n.settingsReadOnly(file.path)),
          ),
        _DirectoryTile(title: l10n.settingsConfigDirectory, path: paths.config),
        _DirectoryTile(title: l10n.settingsDataDirectory, path: paths.data),
        _DirectoryTile(title: l10n.settingsCacheDirectory, path: paths.cache),
        ListTile(
          leading: const Icon(Icons.restart_alt),
          title: Text(l10n.settingsReset),
          onTap: () => _confirmReset(context, ref),
        ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsResetConfirmTitle),
        content: Text(l10n.settingsResetConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settingsResetConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(settingsProvider.notifier).reset();
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsResetDone)));
  }
}

class _DirectoryTile extends ConsumerWidget {
  const _DirectoryTile({required this.title, required this.path});

  final String title;
  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final path = this.path;

    return ListTile(
      title: Text(title),
      subtitle: SelectableText(path ?? l10n.settingsDirectoryUnknown),
      trailing: path == null
          ? null
          : IconButton(
              icon: const Icon(Icons.folder_open_outlined),
              tooltip: l10n.settingsOpenDirectory,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final opened = await openDirectory(
                  path,
                  open: ref.read(openExternalProvider),
                );
                if (opened) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.settingsOpenFailed(path))),
                );
              },
            ),
    );
  }
}
