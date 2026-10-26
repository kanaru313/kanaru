import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_play_writes.dart';
import '../../core/database/library_database.dart';
import '../../l10n/l10n.dart';
import 'history_error_log.dart';
import 'history_plays_version.dart';
import '../../shared/widgets/app_snack_bar.dart';

/// How long the Undo snackbar stays.
const historyUndoDuration = Duration(seconds: 4);

/// The Undo snackbar shown or waiting behind other messages.
class _UndoMessage {
  _UndoMessage(this.play, this.messenger);

  /// The play Undo puts back: the latest one removed.
  Play play;
  final ScaffoldMessengerState messenger;
  late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  controller;

  /// The snackbar finished appearing, so its time on screen is running and a
  /// new play could not get a time of its own.
  bool visible = false;
  bool closed = false;
}

/// The one [HistoryDeleteUndo] of the app. The pages that remove plays (the
/// timeline of a year, the page of a song) come and go, and each would
/// otherwise keep an Undo snackbar of its own beside the others.
final historyDeleteUndoProvider = Provider<HistoryDeleteUndo>(
  (ref) => HistoryDeleteUndo(),
);

/// Removes plays from the History and offers to put the last one back.
///
/// Only the latest removal can be undone, and only while its snackbar is on
/// screen ([historyUndoDuration]). Removing again while the snackbar is
/// visible replaces it with a new one; while it still waits behind another
/// message (a scan result) it is updated in place. Only this
/// class's own snackbar is ever closed (one instance serves the whole app,
/// see [historyDeleteUndoProvider]): closing the messenger's current snackbar when it
/// is another one would hide that one instead.
///
/// Nothing here reads a `BuildContext` or a `Ref` after an `await`: the
/// database, the messenger, the strings and the version notifier are all
/// passed in, as the page may be gone when the Undo is pressed.
class HistoryDeleteUndo {
  _UndoMessage? _pending;

  /// Deletes play [playId] and shows the Undo snackbar. A play already gone
  /// says nothing.
  Future<void> delete({
    required LibraryDatabase db,
    required ScaffoldMessengerState messenger,
    required AppLocalizations l10n,
    required HistoryPlaysVersion version,
    required int playId,
  }) async {
    final Play? play;
    try {
      play = await db.deletePlay(playId);
    } on Object catch (error) {
      logHistoryError('Removing a play failed', error);
      _say(messenger, l10n.historyDeleteFailed);
      return;
    }
    if (play == null) return;
    _showUndo(db, messenger, l10n, version, play);
  }

  void _showUndo(
    LibraryDatabase db,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    HistoryPlaysVersion version,
    Play play,
  ) {
    if (!messenger.mounted) return;
    final earlier = _pending;
    if (earlier != null &&
        !earlier.closed &&
        identical(earlier.messenger, messenger)) {
      if (!earlier.visible) {
        earlier.play = play;
        return;
      }
      earlier.controller.close();
    }
    final message = _UndoMessage(play, messenger);
    message.controller = messenger.showSnackBar(
      appSnackBar(
        kind: AppSnackBarKind.success,
        persist: false,
        duration: historyUndoDuration,
        onVisible: () => message.visible = true,
        title: l10n.historyPlayDeleted,
        action: SnackBarAction(
          label: l10n.historyUndo,
          onPressed: () =>
              unawaited(_restore(db, messenger, l10n, version, message.play)),
        ),
      ),
    );
    _pending = message;
    unawaited(
      message.controller.closed.then((_) {
        message.closed = true;
        if (identical(_pending, message)) _pending = null;
      }),
    );
  }

  Future<void> _restore(
    LibraryDatabase db,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    HistoryPlaysVersion version,
    Play play,
  ) async {
    // The put-back play is a new row to the page, which would hold it back
    // when scrolled away from the top.
    try {
      await version.applyOwnInsert(() => db.restorePlay(play));
    } on Object catch (error) {
      logHistoryError('Restoring a play failed', error);
      _say(messenger, l10n.historyRestoreFailed);
    }
  }

  void _say(ScaffoldMessengerState messenger, String text) {
    if (messenger.mounted) {
      messenger.showSnackBar(
        appSnackBar(kind: AppSnackBarKind.error, title: text),
      );
    }
  }
}
