import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'settings_section.dart';

class AdvancedSettingsSection extends ConsumerWidget {
  const AdvancedSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final file = ref.watch(settingsFileProvider);
    final saveFailed = ref.watch(settingsSaveFailedProvider);

    return SettingsSection(
      title: l10n.settingsAdvanced,
      children: [
        if (file != null && (file.readOnly || saveFailed))
          ListTile(
            leading: Icon(
              Icons.warning_amber_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(l10n.settingsReadOnly(file.path)),
          ),
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
    final notifier = ref.read(settingsProvider.notifier);
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
    notifier.reset();
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsResetDone)));
  }
}
