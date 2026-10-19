import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';

/// Tells the user that changes will not survive a restart: the settings file
/// could not be read safely at startup, or the last write failed. Takes no
/// space otherwise.
class SettingsSaveWarning extends ConsumerWidget {
  const SettingsSaveWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(settingsFileProvider);
    final saveFailed = ref.watch(settingsSaveFailedProvider);
    if (file == null || !(file.readOnly || saveFailed)) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: Icon(
        Icons.warning_amber_outlined,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(context.l10n.settingsReadOnly(file.path)),
    );
  }
}
