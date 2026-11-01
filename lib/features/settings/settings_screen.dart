import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/lyrics_source_routes.dart';
import '../../shared/settings_routes.dart';
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
        SettingsCategoryTile(
          icon: AppIcons.settingsAppearance,
          title: l10n.settingsAppearance,
          description: l10n.settingsAppearanceDescription,
          onTap: () => context.go(settingsAppearanceRoute),
        ),
        SettingsCategoryTile(
          icon: AppIcons.settingsPlayback,
          title: l10n.settingsPlayback,
          description: l10n.settingsPlaybackDescription,
          onTap: () => context.go(settingsPlaybackRoute),
        ),
        SettingsCategoryTile(
          icon: AppIcons.library,
          title: l10n.settingsLibrary,
          description: l10n.settingsLibraryDescription,
          onTap: () => context.go(settingsLibraryRoute),
        ),
        SettingsCategoryTile(
          icon: AppIcons.extension,
          title: l10n.settingsPlugins,
          description: l10n.settingsPluginsDescription,
          onTap: () => context.go(lyricsStoreRoute),
        ),
        SettingsCategoryTile(
          icon: AppIcons.settingsData,
          title: l10n.settingsDataStorage,
          description: l10n.settingsDataStorageDescription,
          onTap: () => context.go(settingsDataRoute),
        ),
        SettingsCategoryTile(
          icon: AppIcons.settingsAbout,
          title: l10n.settingsAbout,
          description: l10n.settingsAboutDescription,
          onTap: () => context.go(settingsAboutRoute),
        ),
      ],
    );
  }
}
