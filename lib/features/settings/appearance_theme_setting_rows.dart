import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'setting_choice.dart';
import 'setting_row.dart';

/// Appearance › Theme: light or dark, colors taken from the cover, and
/// motion. All apply at once.
class AppearanceThemeSettingRows extends ConsumerWidget {
  const AppearanceThemeSettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow(
          title: l10n.settingsTheme,
          subtitle: l10n.settingsThemeHint,
          control: (compact) => SettingChoice<ThemePreference>(
            compact: compact,
            options: [
              SettingOption(
                value: ThemePreference.system,
                icon: AppIcons.themeSystem,
                label: l10n.settingsThemeSystem,
              ),
              SettingOption(
                value: ThemePreference.light,
                icon: AppIcons.themeLight,
                label: l10n.settingsThemeLight,
              ),
              SettingOption(
                value: ThemePreference.dark,
                icon: AppIcons.themeDark,
                label: l10n.settingsThemeDark,
              ),
            ],
            selected: settings.theme,
            onSelected: notifier.setTheme,
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
          title: l10n.settingsAnimations,
          subtitle: l10n.settingsAnimationsHint,
          control: Switch(
            value: settings.animations,
            onChanged: notifier.setAnimations,
          ),
        ),
      ],
    );
  }
}
