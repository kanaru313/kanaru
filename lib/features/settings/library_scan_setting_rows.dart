import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'coming_soon_rows.dart';
import 'setting_row.dart';
import 'settings_chips_row.dart';
import 'settings_number_presets.dart';

/// Scan options that are not wired yet (shown from the saved values, off):
/// what a scan skips, how albums are grouped, and the cover cache.
class LibraryScanSettingRows extends ConsumerWidget {
  const LibraryScanSettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scan = ref.watch(settingsProvider.select((s) => s.libraryScan));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComingSoonSwitchRow(
          title: l10n.settingsRespectNomedia,
          subtitle: l10n.settingsRespectNomediaHint,
          value: scan.respectNomedia,
        ),
        ComingSoonSwitchRow(
          title: l10n.settingsDuplicatesByFilename,
          subtitle: l10n.settingsDuplicatesByFilenameHint,
          value: scan.duplicatesByFilename,
        ),
        ComingSoonSwitchRow(
          title: l10n.settingsM3uPlaylists,
          subtitle: l10n.settingsM3uPlaylistsHint,
          value: scan.m3uPlaylists,
        ),
        SettingsChipsRow(
          title: l10n.settingsAlbumGrouping,
          subtitle: l10n.settingsAlbumGroupingHint,
          comingSoon: true,
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
              onSelected: null,
            ),
            FilterChip(
              label: Text(l10n.settingsAlbumGroupYear),
              selected: scan.albumGrouping.byYear,
              onSelected: null,
            ),
          ],
        ),
        ComingSoonDropdownRow<int>(
          title: l10n.settingsMinFileSize,
          subtitle: l10n.settingsMinFileSizeHint,
          options: presetOptions(
            minFileSizePresetsKb,
            scan.minFileSizeKb,
            (kb) => formatFileSizeKb(l10n, kb),
          ),
          selected: scan.minFileSizeKb,
        ),
        ComingSoonDropdownRow<int>(
          title: l10n.settingsMinDuration,
          subtitle: l10n.settingsMinDurationHint,
          options: presetOptions(
            minDurationPresetsSeconds,
            scan.minDurationSeconds,
            (s) => formatSeconds(l10n, s),
          ),
          selected: scan.minDurationSeconds,
        ),
        SettingRow.single(
          title: l10n.settingsClearCoverCache,
          subtitle: l10n.settingsClearCoverCacheHint,
          comingSoon: true,
          control: FilledButton.tonal(
            style: settingButtonStyle().copyWith(
              foregroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.error,
              ),
            ),
            onPressed: null,
            child: Text(
              l10n.settingsClearCoverCacheButton,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
