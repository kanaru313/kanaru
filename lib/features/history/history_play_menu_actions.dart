import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import 'history_day_queue.dart';
import 'history_delete_undo.dart';
import 'history_play_menu.dart';
import 'history_plays_version.dart';
import 'history_routes.dart';

/// The menu of one play row, shared by the timeline and the filter results.
mixin HistoryPlayMenuActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Opens the menu of [row]. The play is the one the menu was opened on:
  /// the list may move before a choice is made.
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
