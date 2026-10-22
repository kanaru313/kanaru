import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'coming_soon_rows.dart';
import 'settings_chips_row.dart';

/// Interface options that are not wired yet (shown from the saved values,
/// off): which sidebar tabs show, and track numbers on album pages.
class InterfaceSettingRows extends ConsumerWidget {
  const InterfaceSettingRows({super.key});

  String _tabLabel(AppLocalizations l10n, SidebarTab tab) => switch (tab) {
    SidebarTab.songs => l10n.navSongs,
    SidebarTab.albums => l10n.navAlbums,
    SidebarTab.artists => l10n.navArtists,
    SidebarTab.folders => l10n.navFolders,
    SidebarTab.genres => l10n.settingsTabGenres,
    SidebarTab.languages => l10n.settingsTabLanguages,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final display = ref.watch(settingsProvider.select((s) => s.display));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsChipsRow(
          title: l10n.settingsSidebarTabs,
          subtitle: l10n.settingsSidebarTabsHint,
          comingSoon: true,
          chips: [
            for (final tab in SidebarTab.values)
              FilterChip(
                label: Text(_tabLabel(l10n, tab)),
                selected: display.sidebarTabs.contains(tab),
                onSelected: null,
              ),
          ],
        ),
        ComingSoonSwitchRow(
          title: l10n.settingsTrackNumbers,
          subtitle: l10n.settingsTrackNumbersHint,
          value: display.trackNumbersInAlbum,
        ),
      ],
    );
  }
}
