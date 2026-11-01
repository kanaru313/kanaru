import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'separator_setting_rows.dart';
import 'settings_chips_row.dart';

/// Library › Organization: the album grouping, which applies at once (the
/// library re-keys in the background), and the artist and genre separators
/// that follow it. Off without a library database, like the scan options.
class LibraryOrganizationSettingRows extends ConsumerWidget {
  const LibraryOrganizationSettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scan = ref.watch(settingsProvider.select((s) => s.libraryScan));
    final settings = ref.read(settingsProvider.notifier);
    final live = ref.watch(libraryDatabaseProvider) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsChipsRow(
          title: l10n.settingsAlbumGrouping,
          subtitle: l10n.settingsAlbumGroupingHint,
          chips: [
            // The title always counts, so this chip is selected for good.
            FilterChip(
              label: Text(l10n.settingsAlbumGroupTitle),
              selected: true,
              onSelected: null,
            ),
            FilterChip(
              label: Text(l10n.settingsAlbumGroupArtist),
              selected: scan.albumGrouping.byAlbumArtist,
              onSelected: live
                  ? (value) => settings.setLibraryScan(
                      scan.copyWith(
                        albumGrouping: AlbumGrouping(
                          byAlbumArtist: value,
                          byYear: scan.albumGrouping.byYear,
                        ),
                      ),
                    )
                  : null,
            ),
            FilterChip(
              label: Text(l10n.settingsAlbumGroupYear),
              selected: scan.albumGrouping.byYear,
              onSelected: live
                  ? (value) => settings.setLibraryScan(
                      scan.copyWith(
                        albumGrouping: AlbumGrouping(
                          byAlbumArtist: scan.albumGrouping.byAlbumArtist,
                          byYear: value,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
        const SeparatorSettingRows(),
      ],
    );
  }
}
