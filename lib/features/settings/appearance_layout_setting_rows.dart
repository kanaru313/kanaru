import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'setting_choice.dart';
import 'setting_divider.dart';
import 'setting_row.dart';

/// Appearance › Layout, after the interface rows: the seek bar style of Now
/// Playing (applies at once) and the title bar (applies after a restart).
class AppearanceLayoutSettingRows extends ConsumerWidget {
  const AppearanceLayoutSettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final initial = ref.watch(initialSettingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow.single(
          title: l10n.settingsWaveformSeekBar,
          subtitle: l10n.settingsWaveformSeekBarHint,
          control: Switch(
            value: settings.display.waveformSeekBar,
            onChanged: (on) => notifier.setDisplay(
              settings.display.copyWith(waveformSeekBar: on),
            ),
          ),
        ),
        const SettingDivider(),
        SettingRow(
          title: l10n.settingsTitleBar,
          subtitle: settings.titleBar != initial.titleBar
              ? l10n.settingsRestartRequired
              : l10n.settingsTitleBarHint,
          control: (compact) => SettingChoice<TitleBarPreference>(
            compact: compact,
            options: [
              SettingOption(
                value: TitleBarPreference.kanaru,
                icon: AppIcons.windowCustom,
                label: l10n.settingsTitleBarKanaru,
              ),
              SettingOption(
                value: TitleBarPreference.system,
                icon: AppIcons.windowSystem,
                label: l10n.settingsTitleBarSystem,
              ),
              SettingOption(
                value: TitleBarPreference.none,
                icon: AppIcons.windowFrameless,
                label: l10n.settingsTitleBarNone,
              ),
            ],
            selected: settings.titleBar,
            onSelected: notifier.setTitleBar,
          ),
        ),
      ],
    );
  }
}
