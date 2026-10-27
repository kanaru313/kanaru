import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_queries.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'history_error_log.dart';
import 'history_queue_track.dart';

/// Replaces the queue with every played song still in the library, the one
/// played last first, and plays from the first. Read when the button is
/// pressed, so a long history costs nothing until then.
Future<void> playAllHistory(WidgetRef ref) => playFromDatabase(
  ref,
  'Reading the played songs failed',
  (db, covers) async => [
    for (final t in await db.historyPlayedTracks())
      historyQueueTrack(t, covers),
  ],
);

/// Queues every played song still in the library, last played first, by
/// [action] (Play next, Add to queue, Add to playlist).
void queueAllHistory(WidgetRef ref, BuildContext context, QueueAction action) =>
    enqueueFromDatabase(
      ref,
      context,
      action,
      context.l10n.navHistory,
      (db, covers) async => [
        for (final t in await db.historyPlayedTracks())
          historyQueueTrack(t, covers),
      ],
    );

/// Shuffles the same songs into the queue. A failed read is logged and
/// reported in a snackbar; leaving the page before the read ends plays
/// nothing.
Future<void> shuffleAllHistory(WidgetRef ref, BuildContext context) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final covers = ref.read(coverCacheDirectoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final played = await db.historyPlayedTracks();
    if (!context.mounted || played.isEmpty) return;
    shuffleTracks(ref, [for (final t in played) historyQueueTrack(t, covers)]);
  } on Object catch (error) {
    logHistoryError('Reading the shuffle queue failed', error);
    if (context.mounted) {
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.libraryUnexpectedError,
        ),
      );
    }
  }
}
