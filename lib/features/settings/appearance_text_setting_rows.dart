import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/fonts/custom_font_providers.dart';
import '../../core/fonts/custom_font_service.dart';
import '../../core/settings/app_font.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/settings_routes.dart';
import 'setting_card.dart';
import 'setting_choice.dart';
import 'setting_row.dart';
import 'settings_number_presets.dart';

/// Label of an [AppFont] shown in settings.
String appFontLabel(AppLocalizations l10n, AppFont font) {
  if (font.id == systemFontId) return l10n.settingsFontSystem;
  return font.label;
}

/// Resolves the display label for [fontId], falling back to [customFonts]
/// metadata when the active font is a user-imported font.
String currentFontLabel(
  AppLocalizations l10n,
  String fontId,
  List<CustomFontItem> customFonts,
) {
  if (isCustomFontId(fontId)) {
    final match = customFonts.where((c) => c.id == fontId).firstOrNull;
    if (match != null) return match.label;
  }
  return appFontLabel(l10n, appFontFor(fontId));
}

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
    final customFonts = ref.watch(customFontsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final languageCode = _languages.any((l) => l.$1 == settings.languageCode)
        ? settings.languageCode!
        : _systemLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingCard(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(l10n.settingsFont),
            subtitle: Text(
              currentFontLabel(l10n, settings.display.fontId, customFonts),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => context.go(settingsAppearanceFontsRoute),
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
