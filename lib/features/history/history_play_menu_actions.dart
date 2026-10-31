import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/song_modal/song_modal_extras.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'history_day_queue.dart';
import 'history_delete_undo.dart';
import 'history_play_menu.dart';
import 'history_plays_version.dart';
import 'history_routes.dart';
import 'history_song_modal_extras.dart';

/// The menu of one play row, shared by the timeline and the filter results:
/// the song modal for a row in the library ([playQueueAction], [playExtras]),
/// the small popup ([openPlayMenu]) for a row whose file is missing.
mixin HistoryPlayMenuActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Queue action picked in the song modal of [row]; dropped once the screen
  /// is gone.
  void playQueueAction(HistoryPlayRow row, QueueAction action) {
    if (!mounted || row.track == null) return;
    enqueueLoaded(ref, context, action, [
      historyTrackOf(row, ref.read(coverCacheDirectoryProvider)),
    ], row.track!.title);
  }

  /// Song history and Remove from history for the modal of [row], built when
  /// the modal opens.
  SongModalExtras playExtras(HistoryPlayRow row) => historyPlayExtras(
    context: context,
    ref: ref,
    path: row.path,
    location: historyTrackLocation,
    playId: row.id,
  );

  /// Opens the popup of [row], used for a row with no song in the library.
  /// The play is the one the menu was opened on: the list may move before a
  /// choice is made.
  Future<void> openPlayMenu(HistoryPlayRow row, Offset position) async {
    final choice = await showHistoryPlayMenu(
      context,
      position,
      canQueue: row.track != null,
    );
    if (choice == null || !mounted) return;
    final action = historyQueueActionOf(choice);
    if (action != null) {
      enqueueLoaded(ref, context, action, [
        historyTrackOf(row, ref.read(coverCacheDirectoryProvider)),
      ], row.track!.title);
      return;
    }
    if (choice == HistoryPlayChoice.trackHistory) {
      context.go(historyTrackLocation(row.path));
      return;
    }
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    unawaited(
      ref
          .read(historyDeleteUndoProvider)
          .delete(
            db: db,
            messenger: ScaffoldMessenger.of(context),
            l10n: context.l10n,
            version: ref.read(historyPlaysVersionProvider.notifier),
            playId: row.id,
          ),
    );
  }
}
