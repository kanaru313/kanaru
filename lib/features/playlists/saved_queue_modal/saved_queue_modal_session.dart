import 'dart:async';

import 'package:logging/logging.dart';

import '../../../core/database/playlist_rows.dart';
import '../../../core/m3u/m3u_write.dart' show M3uPathStyle;
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../playlist_play_actions.dart';
import '../queue_history_routes.dart';
import 'saved_queue_modal_data.dart';
import 'saved_queue_modal_session_actions.dart';

final _log = Logger('queue_history');

/// What one open saved-queue modal holds: the queue as it was when the modal
/// opened and the [runner], which captured everything its actions need from
/// the widget tree before the modal opened. The row or page that opened it may
/// be rebuilt away meanwhile, so nothing here refers to its own
/// `BuildContext`. Its lifetime is one open modal.
class SavedQueueModalSession {
  SavedQueueModalSession({
    required this.playlist,
    required this.coverKeys,
    required this.runner,
    this.showGoTo = true,
    this.beforeRead,
  });

  /// The summary the modal was opened with. Handlers prefer the latest one.
  final PlaylistSummary playlist;
  final List<String> coverKeys;
  final TrackMenuRunner runner;

  /// False on the page of the queue itself.
  final bool showGoTo;

  /// Completes when the opener has no write in flight. Awaited before
  /// anything reads or writes the entries.
  final Future<void> Function()? beforeRead;

  /// True while a confirm dialog is open above the modal: a second tap
  /// meanwhile must not stack another one.
  bool dialogOpen = false;

  /// Waits for [beforeRead]; a failure there is logged, never blocks the
  /// action.
  Future<void> ready() async {
    try {
      await beforeRead?.call();
    } catch (error, stack) {
      _log.warning('Waiting for the queue writes failed', error, stack);
    }
  }

  /// Shows [text] in the opener's messenger; never throws.
  void say(AppSnackBarKind kind, String text) {
    try {
      runner.messenger?.showAppSnackBar(kind, text);
    } catch (error, stack) {
      _log.warning('Showing the queue message failed', error, stack);
    }
  }

  /// Queue buttons of the footer for [latest].
  void queue(QueueAction action, PlaylistSummary latest) {
    runner.queueHost?.enqueueFromDatabase(action, latest.name, (
      db,
      covers,
    ) async {
      await ready();
      return readPlaylistQueue(db, latest.id, covers);
    });
  }

  /// The callbacks the actions call; [latest] is the newest summary the page
  /// has (the loaded head's, else the snapshot), under its shown name.
  SavedQueueModalHandlers handlers({
    required PlaylistSummary latest,
    void Function(ContextModalNav nav)? openAdvanced,
  }) {
    final id = latest.id;
    return SavedQueueModalHandlers(
      openAdvanced: openAdvanced,
      goToQueue: () => runner.goTo(queueHistoryLocation(id)),
      play: () => unawaited(play(id)),
      shuffle: () => unawaited(play(id, shuffle: true)),
      addToPlaylist: () => addToPlaylist(latest),
      delete: (nav) => unawaited(deleteQueue(nav, latest)),
      addAllToFavorites: () => unawaited(addAllToFavorites(latest)),
      exportAbsolute: () => unawaited(export(latest, M3uPathStyle.absolute)),
      exportRelative: () => unawaited(export(latest, M3uPathStyle.relative)),
      removeMissing: (nav) => unawaited(confirmRemoveMissing(nav, latest)),
    );
  }
}
