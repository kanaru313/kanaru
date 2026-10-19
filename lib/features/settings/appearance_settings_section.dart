import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'settings_section.dart';

/// Language names stay in their own language so they can always be found.
const _languages = [('en', 'English'), ('vi', 'Tiếng Việt')];

/// Dropdown value for "follow the system language".
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
        ListTile(
          title: Text(l10n.settingsTheme),
          trailing: SegmentedButton<ThemePreference>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ThemePreference.system,
                icon: const Icon(Icons.brightness_auto_outlined),
                label: Text(l10n.settingsThemeSystem),
              ),
              ButtonSegment(
                value: ThemePreference.light,
                icon: const Icon(Icons.light_mode_outlined),
                label: Text(l10n.settingsThemeLight),
              ),
              ButtonSegment(
                value: ThemePreference.dark,
                icon: const Icon(Icons.dark_mode_outlined),
                label: Text(l10n.settingsThemeDark),
              ),
            ],
            selected: {settings.theme},
            onSelectionChanged: (s) => notifier.setTheme(s.single),
          ),
        ),
        ListTile(
          title: Text(l10n.settingsLanguage),
          trailing: DropdownMenu<String>(
            // Rebuilt when the value or the UI language changes, since
            // initialSelection is only read once.
            key: ValueKey('$languageCode-${Localizations.localeOf(context)}'),
            initialSelection: languageCode,
            requestFocusOnTap: false,
            enableFilter: false,
            dropdownMenuEntries: [
              DropdownMenuEntry(
                value: _systemLanguage,
                label: l10n.settingsLanguageSystem,
              ),
              for (final (code, name) in _languages)
                DropdownMenuEntry(value: code, label: name),
            ],
            onSelected: (code) => notifier.setLanguage(
              code == null || code == _systemLanguage ? null : code,
            ),
          ),
        ),
        ListTile(
          title: Text(l10n.settingsTitleBar),
          subtitle: settings.titleBar != initial.titleBar
              ? Text(l10n.settingsRestartRequired)
              : null,
          trailing: SegmentedButton<TitleBarPreference>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: TitleBarPreference.kanaru,
                label: Text(l10n.settingsTitleBarKanaru),
              ),
              ButtonSegment(
                value: TitleBarPreference.system,
                label: Text(l10n.settingsTitleBarSystem),
              ),
              ButtonSegment(
                value: TitleBarPreference.none,
                label: Text(l10n.settingsTitleBarNone),
              ),
            ],
            selected: {settings.titleBar},
            onSelectionChanged: (s) => notifier.setTitleBar(s.single),
          ),
        ),
      ],
    );
  }
}
