import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_play_writes.dart';
import '../../core/database/library_database.dart';
import '../../core/stats/listen_clear_scope.dart';
import '../../core/stats/listen_recorder_provider.dart';
import '../../l10n/l10n.dart';
import 'history_error_log.dart';
import 'history_plays_version.dart';
import 'history_undo_message.dart';
import '../../shared/widgets/app_snack_bar.dart';

/// How long the Undo snackbar stays.
const historyUndoDuration = Duration(seconds: 4);

/// The one [HistoryDeleteUndo] of the app. The pages that remove plays (the
/// timeline of a year, the page of a song) come and go, and each would
/// otherwise keep an Undo snackbar of its own beside the others.
final historyDeleteUndoProvider = Provider<HistoryDeleteUndo>((ref) {
  final undo = HistoryDeleteUndo();
  // Follows the recorder, so a clear from Settings or the History modal drops
  // what Undo could still bring back.
  ref.listen(
    listenRecorderProvider,
    (_, recorder) => undo.watchClears(recorder?.cleared),
    fireImmediately: true,
  );
  ref.onDispose(() => undo.watchClears(null));
  return undo;
});

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
  UndoMessage? _pending;
  StreamSubscription<ClearBounds>? _clears;

  /// Number of clears seen so far; a delete in flight compares it with the
  /// value it started with.
  int _generation = 0;
  int _inFlight = 0;

  /// Clears that landed while a delete was in flight, for that delete.
  final _recent = <({int generation, ClearBounds bounds})>[];

  /// Follows [clears] (the recorder's `cleared`) instead of the previous
  /// stream; `null` stops following.
  void watchClears(Stream<ClearBounds>? clears) {
    unawaited(_clears?.cancel());
    _clears = clears?.listen(_onCleared);
  }

  void _onCleared(ClearBounds bounds) {
    _generation++;
    if (_inFlight > 0) _recent.add((generation: _generation, bounds: bounds));
    final message = _pending;
    if (message == null || message.closed || message.undone) return;
    message.dropCleared(bounds);
    // A snackbar that still waits is never closed here (it would hide the
    // message on screen); it closes when it appears.
    if (message.plays.isEmpty && message.visible) message.controller.close();
  }

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
    final startedAt = _generation;
    _inFlight++;
    List<Play>? kept;
    try {
      final removed = await db.deletePlaysByIds(playIds);
      // A clear that landed meanwhile removed what Undo could restore.
      kept = [
        for (final p in removed)
          if (!_recent.any(
            (c) =>
                c.generation > startedAt && boundsCover(c.bounds, p.playedAt),
          ))
            p,
      ];
    } on Object catch (error) {
      logHistoryError('Removing plays failed', error);
      _say(messenger, l10n.historyDeleteFailed);
    } finally {
      if (--_inFlight == 0) _recent.clear();
    }
    if (kept == null || kept.isEmpty) return;
    _showUndo(db, messenger, l10n, version, kept);
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
    final message = UndoMessage(mergePlaysById(carried, removed), messenger);
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
        onVisible: () {
          message.visible = true;
          if (message.plays.isEmpty) message.controller.close();
        },
        action: SnackBarAction(
          label: l10n.historyUndo,
          onPressed: () {
            message.undone = true;
            if (message.plays.isEmpty) return;
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
