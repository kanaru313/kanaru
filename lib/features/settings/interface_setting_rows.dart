import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'setting_row.dart';
import 'settings_chips_row.dart';

/// Chip order: the order the sidebar lists the tabs (a test keeps it equal to
/// `sidebarLibraryOrder`; features cannot import `app/`).
const sidebarTabChipOrder = <SidebarTab>[
  SidebarTab.songs,
  SidebarTab.albums,
  SidebarTab.artists,
  SidebarTab.genres,
  SidebarTab.languages,
  SidebarTab.folders,
];

/// Interface options: which library tabs the sidebar shows, and track numbers
/// on album pages.
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
    final tabs = display.sidebarTabs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsChipsRow(
          title: l10n.settingsSidebarTabs,
          subtitle: l10n.settingsSidebarTabsHint,
          chips: [
            for (final tab in sidebarTabChipOrder)
              FilterChip(
                label: Text(_tabLabel(l10n, tab)),
                selected: tabs.contains(tab),
                // The last tab shown stays: the set is never empty.
                onSelected: tabs.contains(tab) && tabs.length == 1
                    ? null
                    : (on) => ref
                          .read(settingsProvider.notifier)
                          .setDisplay(
                            display.copyWith(
                              sidebarTabs: on
                                  ? {...tabs, tab}
                                  : ({...tabs}..remove(tab)),
                            ),
                          ),
              ),
          ],
        ),
        SettingRow.single(
          title: l10n.settingsTrackNumbers,
          subtitle: l10n.settingsTrackNumbersHint,
          control: Switch(
            value: display.trackNumbersInAlbum,
            onChanged: (on) => ref
                .read(settingsProvider.notifier)
                .setDisplay(display.copyWith(trackNumbersInAlbum: on)),
          ),
        ),
      ],
    );
  }
}
