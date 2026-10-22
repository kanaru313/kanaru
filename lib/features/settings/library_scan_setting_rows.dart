import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'coming_soon_rows.dart';
import 'setting_choice.dart';
import 'setting_row.dart';
import 'settings_chips_row.dart';
import 'settings_number_presets.dart';

/// Scan options: what a scan skips (folders with `.nomedia`, small files,
/// short tracks), which work from the next scan on, and those not wired yet
/// (shown from the saved values, off): duplicates, playlists, album grouping
/// and the cover cache. Skip options are off without a library database,
/// like "rescan on open".
class LibraryScanSettingRows extends ConsumerWidget {
  const LibraryScanSettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scan = ref.watch(settingsProvider.select((s) => s.libraryScan));
    final settings = ref.read(settingsProvider.notifier);
    final live = ref.watch(libraryDatabaseProvider) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow.single(
          title: l10n.settingsRespectNomedia,
          subtitle: l10n.settingsRespectNomediaHint,
          control: Switch(
            value: scan.respectNomedia,
            onChanged: live
                ? (value) => settings.setLibraryScan(
                    scan.copyWith(respectNomedia: value),
                  )
                : null,
          ),
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
        SettingRow.single(
          title: l10n.settingsMinFileSize,
          subtitle: l10n.settingsMinFileSizeHint,
          control: SettingDropdown<int>(
            options: presetOptions(
              minFileSizePresetsKb,
              scan.minFileSizeKb,
              (kb) => formatFileSizeKb(l10n, kb),
            ),
            selected: scan.minFileSizeKb,
            enabled: live,
            onSelected: (kb) =>
                settings.setLibraryScan(scan.copyWith(minFileSizeKb: kb)),
          ),
        ),
        SettingRow.single(
          title: l10n.settingsMinDuration,
          subtitle: l10n.settingsMinDurationHint,
          control: SettingDropdown<int>(
            options: presetOptions(
              minDurationPresetsSeconds,
              scan.minDurationSeconds,
              (s) => formatSeconds(l10n, s),
            ),
            selected: scan.minDurationSeconds,
            enabled: live,
            onSelected: (seconds) => settings.setLibraryScan(
              scan.copyWith(minDurationSeconds: seconds),
            ),
          ),
        ),
        SettingRow.single(
          title: l10n.settingsClearCoverCache,
          subtitle: l10n.settingsClearCoverCacheHint,
          comingSoon: true,
          control: FilledButton.tonal(
            style: settingButtonStyle().copyWith(
              // Red only while live; disabled keeps the normal disabled color.
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? null
                    : Theme.of(context).colorScheme.error,
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
