import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'library_stats_provider.dart';

/// First row of the library section: how many tracks, albums, artists and
/// genres the library holds, live while a scan runs. A row without a control,
/// laid out like a `SettingRow`. Hidden without a library; shows "…" until
/// the first count is in, "—" if the first count fails, and keeps the last
/// count if a later reload fails.
class LibraryStatsRow extends ConsumerWidget {
  const LibraryStatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(libraryStatsProvider);
    // Loaded, and there is no library to count.
    if (stats.hasValue && stats.value == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final value = stats.value;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.settingsLibraryStats, style: theme.textTheme.bodyLarge),
            Text(
              value == null
                  ? (stats.hasError ? '—' : '…')
                  : [
                      l10n.settingsStatsTracks(value.tracks),
                      l10n.settingsStatsAlbums(value.albums),
                      l10n.settingsStatsArtists(value.artists),
                      l10n.settingsStatsGenres(value.genres),
                    ].join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
