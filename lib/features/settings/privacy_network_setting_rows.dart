import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'online_lyrics_consent_setting_row.dart';
import 'setting_row.dart';

/// Privacy & Network settings: confirm before uninstalling plugins, and online lyrics consent.
class PrivacyNetworkSettingRows extends ConsumerWidget {
  const PrivacyNetworkSettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow.single(
          title: l10n.settingsConfirmPluginUninstall,
          subtitle: l10n.settingsConfirmPluginUninstallHint,
          control: Switch(
            value: ref.watch(
              settingsProvider.select((s) => s.confirmPluginUninstall),
            ),
            onChanged: (on) => ref
                .read(settingsProvider.notifier)
                .setConfirmPluginUninstall(on),
          ),
        ),
        const OnlineLyricsConsentSettingRow(),
      ],
    );
  }
}
