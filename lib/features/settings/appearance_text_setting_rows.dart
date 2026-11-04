import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/app_font.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'setting_choice.dart';
import 'setting_divider.dart';
import 'setting_row.dart';
import 'settings_number_presets.dart';

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

/// Appearance › Text: the font, the text size and the language. All apply
/// at once.
class AppearanceTextSettingRows extends ConsumerWidget {
  const AppearanceTextSettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final languageCode = _languages.any((l) => l.$1 == settings.languageCode)
        ? settings.languageCode!
        : _systemLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow.single(
          title: l10n.settingsFont,
          subtitle: l10n.settingsFontHint,
          control: SettingDropdown<String>(
            options: [
              for (final font in builtInAppFonts)
                SettingOption(
                  value: font.id,
                  label: font.id == systemFontId
                      ? l10n.settingsFontSystem
                      : font.label,
                  labelStyle: TextStyle(fontFamily: font.family),
                ),
            ],
            // An unknown stored id shows the default font.
            selected: appFontFor(settings.display.fontId).id,
            onSelected: (id) =>
                notifier.setDisplay(settings.display.copyWith(fontId: id)),
          ),
        ),
        const SettingDivider(),
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
        const SettingDivider(),
        SettingRow.single(
          title: l10n.settingsLanguage,
          subtitle: l10n.settingsLanguageHint,
          control: SettingDropdown<String>(
            leadingIcon: AppIcons.language,
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
      ],
    );
  }
}
