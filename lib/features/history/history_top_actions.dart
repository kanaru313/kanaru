import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/add_to_playlist/create_playlist_prompt.dart';
import 'history_range.dart';
import 'history_top_queue.dart';
import '../../shared/widgets/app_snack_bar.dart';

/// "Play all" and "Create playlist" for the Most played list, and a note when
/// the list was cut at [historyTopLimit]. Both buttons work on the songs that
/// can play (those still in the library), in rank order, and are off when
/// there are none. [rangeText] names the playlist.
class HistoryTopActions extends ConsumerWidget {
  const HistoryTopActions({
    super.key,
    required this.rows,
    required this.rangeText,
    this.capped = false,
  });

  final List<HistoryTopRow> rows;
  final String rangeText;

  /// More songs were played than [rows] holds.
  final bool capped;

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final paths = [for (final row in rows) ?row.track?.path];
    final created = await promptAndCreatePlaylist(
      context,
      db,
      messenger,
      l10n,
      paths: paths,
      initialName: l10n.historyTopPlaylistName(rangeText),
    );
    if (created == null) return;
    messenger.showSnackBar(
      appSnackBar(
        kind: AppSnackBarKind.success,
        title: l10n.historyPlaylistCreated(created.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final playable = rows.any((r) => r.track != null);
    final small = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            icon: const Icon(AppIcons.play),
            label: Text(l10n.historyPlayAll),
            onPressed: playable
                ? () => playTracks(
                    ref,
                    historyTopPlayable(
                      rows,
                      ref.read(coverCacheDirectoryProvider),
                    ),
                    0,
                  )
                : null,
          ),
          OutlinedButton.icon(
            icon: const Icon(AppIcons.newPlaylist),
            label: Text(l10n.historyCreatePlaylist),
            onPressed: playable
                ? () => unawaited(_createPlaylist(context, ref))
                : null,
          ),
          if (capped)
            Text(l10n.historyTopCapped(historyTopLimit), style: small),
        ],
      ),
    );
  }
}
