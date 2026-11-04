import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/lyrics_source_routes.dart';
import '../../shared/settings_routes.dart';
import 'setting_divider.dart';
import 'settings_category_tile.dart';
import 'settings_page_scaffold.dart';

/// The Settings root: one tile per category. Each tile opens its page with
/// `go` (a push from here, so back is a pop to this list).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SettingsPageScaffold(
      title: l10n.navSettings,
      children: [
        const SizedBox(height: 8),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsCategoryTile(
                icon: AppIcons.settingsAppearance,
                title: l10n.settingsAppearance,
                description: l10n.settingsAppearanceDescription,
                onTap: () => context.go(settingsAppearanceRoute),
              ),
              const SettingDivider(),
              SettingsCategoryTile(
                icon: AppIcons.settingsPlayback,
                title: l10n.settingsPlayback,
                description: l10n.settingsPlaybackDescription,
                onTap: () => context.go(settingsPlaybackRoute),
              ),
              const SettingDivider(),
              SettingsCategoryTile(
                icon: AppIcons.library,
                title: l10n.settingsLibrary,
                description: l10n.settingsLibraryDescription,
                onTap: () => context.go(settingsLibraryRoute),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsCategoryTile(
                icon: AppIcons.extension,
                title: l10n.settingsPlugins,
                description: l10n.settingsPluginsDescription,
                onTap: () => context.go(lyricsStoreRoute),
              ),
              const SettingDivider(),
              SettingsCategoryTile(
                icon: AppIcons.settingsData,
                title: l10n.settingsDataStorage,
                description: l10n.settingsDataStorageDescription,
                onTap: () => context.go(settingsDataRoute),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsCategoryTile(
                icon: AppIcons.settingsAdvanced,
                title: l10n.settingsAdvanced,
                description: l10n.settingsAdvancedDescription,
                onTap: () => context.go(settingsAdvancedRoute),
              ),
              const SettingDivider(),
              SettingsCategoryTile(
                icon: AppIcons.settingsAbout,
                title: l10n.settingsAbout,
                description: l10n.settingsAboutDescription,
                onTap: () => context.go(settingsAboutRoute),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
