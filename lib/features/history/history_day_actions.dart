import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/add_to_playlist/create_playlist_prompt.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'history_day_menu.dart';
import 'history_day_queue.dart';
import 'history_delete_undo.dart';
import 'history_error_log.dart';
import 'history_plays_version.dart';

/// Opens the menu of the day bar of [day] at [position] (global) and runs the
/// choice.
///
/// The menu works on the plays the page shows for the day: [readDay] reads
/// them when the menu is asked for (with the page's cut of plays that are
/// held back), and that snapshot is what every action uses. A play recorded
/// while the menu is open is never part of it, so Remove deletes exactly the
/// rows the reader saw.
///
/// Everything the actions need from [ref] is read before the first `await`:
/// the page may be gone when the choice is made. Removing still runs then;
/// the actions that open dialogs or queue songs need the page ([context]).
Future<void> runHistoryDayMenu(
  WidgetRef ref,
  BuildContext context, {
  required DateTime day,
  required Future<List<HistoryPlayRow>> Function() readDay,
  required Offset position,
}) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final covers = ref.read(coverCacheDirectoryProvider);
  final version = ref.read(historyPlaysVersionProvider.notifier);
  final undo = ref.read(historyDeleteUndoProvider);
  final List<HistoryPlayRow> rows;
  final HistoryDayChoice? choice;
  try {
    rows = await readDay();
    if (!context.mounted) return;
    choice = await showHistoryDayMenu(
      context,
      position,
      canQueue: rows.any((r) => r.track != null),
    );
  } on Object catch (error) {
    logHistoryError('Opening the menu of a day failed', error);
    if (messenger.mounted) {
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.libraryUnexpectedError,
        ),
      );
    }
    return;
  }
  if (choice == null) return;
  if (choice == HistoryDayChoice.delete) {
    await undo.deleteMany(
      db: db,
      messenger: messenger,
      l10n: l10n,
      version: version,
      playIds: [for (final r in rows) r.id],
    );
    return;
  }
  if (!context.mounted) return;
  final tracks = historyDayTracks(rows, covers);
  if (tracks.isEmpty) return;
  switch (choice) {
    case HistoryDayChoice.playAll:
      playTracks(ref, tracks, 0);
    case HistoryDayChoice.playNext:
      enqueueLoaded(
        ref,
        context,
        QueueAction.playNext,
        tracks,
        l10n.historyDayDate(day),
      );
    case HistoryDayChoice.addToQueue:
      enqueueLoaded(
        ref,
        context,
        QueueAction.addToQueue,
        tracks,
        l10n.historyDayDate(day),
      );
    case HistoryDayChoice.createPlaylist:
      final created = await promptAndCreatePlaylist(
        context,
        db,
        messenger,
        l10n,
        paths: [for (final t in tracks) t.uri],
        initialName: l10n.historyDayPlaylistName(day),
      );
      if (created != null && messenger.mounted) {
        messenger.showSnackBar(
          appSnackBar(
            kind: AppSnackBarKind.success,
            title: l10n.historyPlaylistCreated(created.name),
          ),
        );
      }
    case HistoryDayChoice.delete:
      break;
  }
}
