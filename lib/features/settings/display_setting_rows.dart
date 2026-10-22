import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'coming_soon_rows.dart';
import 'settings_number_presets.dart';

/// Appearance options that are not wired yet (shown from the saved values,
/// off): motion, colors from the cover, and text size.
class DisplaySettingRows extends ConsumerWidget {
  const DisplaySettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComingSoonSwitchRow(
          title: l10n.settingsAnimations,
          subtitle: l10n.settingsAnimationsHint,
          value: settings.animations,
        ),
        ComingSoonSwitchRow(
          title: l10n.settingsColorFromCover,
          subtitle: l10n.settingsColorFromCoverHint,
          value: settings.display.colorFromCover,
        ),
        ComingSoonDropdownRow<double>(
          title: l10n.settingsFontScale,
          subtitle: l10n.settingsFontScaleHint,
          options: presetOptions(
            fontScalePresets,
            settings.display.fontScale,
            (scale) => formatScale(l10n, scale),
          ),
          selected: settings.display.fontScale,
        ),
      ],
    );
  }
}
