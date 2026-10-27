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
  _UndoMessage(this.plays, this.messenger)
    : count = ValueNotifier(plays.length);

  /// Every play removed since the first snackbar of this run appeared: what
  /// Undo puts back.
  final List<Play> plays;

  /// Length of [plays], for the title of a snackbar that is still waiting.
  final ValueNotifier<int> count;
  final ScaffoldMessengerState messenger;
  late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  controller;

  /// The snackbar finished appearing, so its time on screen is running and new
  /// plays could not get a time of their own.
  bool visible = false;
  bool closed = false;

  /// Undo was pressed. The snackbar may still be leaving, but its plays are
  /// already restored, so a later removal must not carry them again.
  bool undone = false;

  void add(List<Play> more) {
    final merged = mergePlaysById(plays, more);
    plays
      ..clear()
      ..addAll(merged);
    count.value = plays.length;
  }
}

/// [first] then [second] without repeats of a play id, in order.
List<Play> mergePlaysById(List<Play> first, List<Play> second) => [
  ...{
    for (final p in [...first, ...second]) p.id: p,
  }.values,
];

/// The one [HistoryDeleteUndo] of the app. The pages that remove plays (the
/// timeline of a year, the page of a song) come and go, and each would
/// otherwise keep an Undo snackbar of its own beside the others.
final historyDeleteUndoProvider = Provider<HistoryDeleteUndo>(
  (ref) => HistoryDeleteUndo(),
);

/// Removes plays from the History and offers to put them back.
///
/// Undo restores every removal made since its snackbar appeared, and only
/// while the snackbar is on screen ([historyUndoDuration]). Removing again
/// while the snackbar is visible closes it and shows a new one that carries
/// the earlier plays too; while it still waits behind another message (a scan
/// result) the plays join it and its title count follows. Only this class's
/// own snackbar is ever closed (one instance serves the whole app, see
/// [historyDeleteUndoProvider]): closing the messenger's current snackbar when
/// it is another one would hide that one instead.
///
/// Nothing here reads a `BuildContext` or a `Ref` after an `await`: the
/// database, the messenger, the strings and the version notifier are all
/// passed in, as the page may be gone when the Undo is pressed. Merged plays
/// are restored through the newest database handle.
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
  }) => deleteMany(
    db: db,
    messenger: messenger,
    l10n: l10n,
    version: version,
    playIds: [playId],
  );

  /// Deletes the plays with [playIds] (the ones the user saw) and shows the
  /// Undo snackbar. Plays already gone are skipped; none left says nothing.
  Future<void> deleteMany({
    required LibraryDatabase db,
    required ScaffoldMessengerState messenger,
    required AppLocalizations l10n,
    required HistoryPlaysVersion version,
    required List<int> playIds,
  }) async {
    final List<Play> removed;
    try {
      removed = await db.deletePlaysByIds(playIds);
    } on Object catch (error) {
      logHistoryError('Removing plays failed', error);
      _say(messenger, l10n.historyDeleteFailed);
      return;
    }
    if (removed.isEmpty) return;
    _showUndo(db, messenger, l10n, version, removed);
  }

  void _showUndo(
    LibraryDatabase db,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    HistoryPlaysVersion version,
    List<Play> removed,
  ) {
    if (!messenger.mounted) return;
    final earlier = _pending;
    var carried = const <Play>[];
    if (earlier != null &&
        !earlier.closed &&
        !earlier.undone &&
        identical(earlier.messenger, messenger)) {
      if (!earlier.visible) {
        earlier.add(removed);
        return;
      }
      carried = List.of(earlier.plays);
      earlier.controller.close();
    }
    final message = _UndoMessage(mergePlaysById(carried, removed), messenger);
    message.controller = messenger.showSnackBar(
      SnackBar(
        content: ValueListenableBuilder<int>(
          valueListenable: message.count,
          builder: (_, count, _) => AppSnackBarContent(
            kind: AppSnackBarKind.success,
            title: l10n.historyPlaysDeleted(count),
          ),
        ),
        persist: false,
        duration: historyUndoDuration,
        onVisible: () => message.visible = true,
        action: SnackBarAction(
          label: l10n.historyUndo,
          onPressed: () {
            message.undone = true;
            unawaited(
              _restore(db, messenger, l10n, version, List.of(message.plays)),
            );
          },
        ),
      ),
    );
    _pending = message;
    unawaited(
      message.controller.closed.then((_) {
        message.closed = true;
        message.count.dispose();
        if (identical(_pending, message)) _pending = null;
      }),
    );
  }

  Future<void> _restore(
    LibraryDatabase db,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    HistoryPlaysVersion version,
    List<Play> plays,
  ) async {
    // The put-back plays are new rows to the page, which would hold them back
    // when scrolled away from the top.
    try {
      await version.applyOwnInsert(
        () async => await db.restorePlays(plays) > 0,
      );
    } on Object catch (error) {
      logHistoryError('Restoring plays failed', error);
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
