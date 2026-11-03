import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_page_queries.dart';
import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/app_snack_bar.dart';

final _log = Logger('queue_history');

/// The name of a saved queue: when it was saved, in the user's language.
String queueSnapshotName(AppLocalizations l10n, int savedAt) {
  final when = DateTime.fromMillisecondsSinceEpoch(savedAt);
  return l10n.queueHistorySavedAt(when, when);
}

/// [summary] of a saved queue under its shown name. The stored name is a
/// placeholder; `created_at` is the time the queue was saved.
PlaylistSummary namedQueueSummary(
  PlaylistSummary summary,
  AppLocalizations l10n,
) => PlaylistSummary(
  id: summary.id,
  name: queueSnapshotName(l10n, summary.createdAt),
  createdAt: summary.createdAt,
  entryCount: summary.entryCount,
);

/// Replaces the player queue with the songs of saved queue [id] that are in
/// the library. The messenger and texts are captured before the first
/// `await`; playing needs [ref], so it is dropped when the row left the tree
/// meanwhile. Failures are logged and reported in a snackbar, never thrown.
Future<void> playQueueSnapshot(
  WidgetRef ref,
  BuildContext context,
  int id,
) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final covers = ref.read(coverCacheDirectoryProvider);
  try {
    final playable = await db.playlistPlayableTracks(id);
    // The row may be gone (deleted, pruned, another page): `ref` with it.
    if (!context.mounted) return;
    final tracks = [for (final p in playable) trackFromRow(p.track, covers)];
    if (tracks.isEmpty) {
      messenger.showAppSnackBar(
        AppSnackBarKind.info,
        l10n.queueHistoryNothingToPlay,
      );
      return;
    }
    playTracks(ref, tracks, 0);
  } catch (error, stack) {
    _log.severe('Playing a saved queue failed', error, stack);
    messenger.showAppSnackBar(
      AppSnackBarKind.error,
      l10n.libraryUnexpectedError,
    );
  }
}
