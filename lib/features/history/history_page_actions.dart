import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_queries.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'history_error_log.dart';

/// Replaces the queue with every played song still in the library, the one
/// played last first, and plays from the first. Read when the button is
/// pressed, so a long history costs nothing until then.
Future<void> playAllHistory(WidgetRef ref) => playFromDatabase(
  ref,
  'Reading the played songs failed',
  (db, covers) async => [
    for (final t in await db.historyPlayedTracks()) trackFromRow(t, covers),
  ],
);

/// Shuffles every played song into the queue. A failed read is logged and
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
    shuffleTracks(ref, [for (final t in played) trackFromRow(t, covers)]);
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
