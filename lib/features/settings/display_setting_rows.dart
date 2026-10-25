import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'setting_choice.dart';
import 'setting_row.dart';
import 'settings_number_presets.dart';

/// Appearance options: motion, colors from the cover, the seek bar style of
/// Now Playing and the text size. All apply at once.
class DisplaySettingRows extends ConsumerWidget {
  const DisplaySettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow.single(
          title: l10n.settingsAnimations,
          subtitle: l10n.settingsAnimationsHint,
          control: Switch(
            value: settings.animations,
            onChanged: notifier.setAnimations,
          ),
        ),
        SettingRow.single(
          title: l10n.settingsColorFromCover,
          subtitle: l10n.settingsColorFromCoverHint,
          control: Switch(
            value: settings.display.colorFromCover,
            onChanged: (on) => notifier.setDisplay(
              settings.display.copyWith(colorFromCover: on),
            ),
          ),
        ),
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
        SettingRow.single(
          title: l10n.settingsFontScale,
          subtitle: l10n.settingsFontScaleHint,
          control: SettingDropdown<double>(
            options: presetOptions(
              fontScalePresets,
              settings.display.fontScale,
              (scale) => formatScale(l10n, scale),
            ),
            selected: settings.display.fontScale,
            onSelected: (scale) => notifier.setDisplay(
              settings.display.copyWith(fontScale: scale),
            ),
          ),
        ),
      ],
    );
  }
}
