import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'setting_choice.dart';
import 'setting_row.dart';
import 'settings_section.dart';

/// Language names stay in their own language so they can always be found.
/// A translation missing here is listed by its language code.
const _nativeNames = {'en': 'English', 'vi': 'Tiếng Việt'};

/// One entry per translation the app ships, so a new one shows up by itself.
final _languages = [
  for (final locale in AppLocalizations.supportedLocales)
    (
      locale.languageCode,
      _nativeNames[locale.languageCode] ?? locale.languageCode,
    ),
];

/// Language value for "follow the system language".
const _systemLanguage = '';

class AppearanceSettingsSection extends ConsumerWidget {
  const AppearanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final initial = ref.watch(initialSettingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final languageCode = _languages.any((l) => l.$1 == settings.languageCode)
        ? settings.languageCode!
        : _systemLanguage;

    return SettingsSection(
      title: l10n.settingsAppearance,
      children: [
        SettingRow(
          title: l10n.settingsTheme,
          control: (compact) => SettingChoice<ThemePreference>(
            compact: compact,
            options: [
              SettingOption(
                value: ThemePreference.system,
                icon: Icons.brightness_auto_outlined,
                label: l10n.settingsThemeSystem,
              ),
              SettingOption(
                value: ThemePreference.light,
                icon: Icons.light_mode_outlined,
                label: l10n.settingsThemeLight,
              ),
              SettingOption(
                value: ThemePreference.dark,
                icon: Icons.dark_mode_outlined,
                label: l10n.settingsThemeDark,
              ),
            ],
            selected: settings.theme,
            onSelected: notifier.setTheme,
          ),
        ),
        SettingRow.single(
          title: l10n.settingsLanguage,
          control: SettingDropdown<String>(
            leadingIcon: Icons.translate,
            options: [
              SettingOption(
                value: _systemLanguage,
                label: l10n.settingsLanguageSystem,
              ),
              for (final (code, name) in _languages)
                SettingOption(value: code, label: name),
            ],
            selected: languageCode,
            onSelected: (code) =>
                notifier.setLanguage(code == _systemLanguage ? null : code),
          ),
        ),
        SettingRow(
          title: l10n.settingsTitleBar,
          subtitle: settings.titleBar != initial.titleBar
              ? l10n.settingsRestartRequired
              : null,
          control: (compact) => SettingChoice<TitleBarPreference>(
            compact: compact,
            options: [
              SettingOption(
                value: TitleBarPreference.kanaru,
                icon: Icons.web_asset,
                label: l10n.settingsTitleBarKanaru,
              ),
              SettingOption(
                value: TitleBarPreference.system,
                icon: Icons.desktop_windows_outlined,
                label: l10n.settingsTitleBarSystem,
              ),
              SettingOption(
                value: TitleBarPreference.none,
                icon: Icons.crop_free,
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
