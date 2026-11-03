import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/song_modal/song_modal_extras.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'history_day_queue.dart';
import 'history_missing_play_modal.dart';
import 'history_routes.dart';
import 'history_song_modal_extras.dart';

/// The menu of one play row, shared by the timeline and the filter results:
/// the song modal for a row in the library ([playQueueAction], [playExtras]),
/// the Missing-play modal ([openMissingPlayModal]) for a row whose file is
/// missing.
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

  /// Song history and Remove from history for the modal of
  /// [row], built when the modal opens.
  SongModalExtras playExtras(HistoryPlayRow row) => historyPlayExtras(
    context: context,
    ref: ref,
    path: row.path,
    location: historyTrackLocation,
    playId: row.id,
  );

  /// Opens the Missing-play modal of [row], a play with no song in the
  /// library. The play is the one the modal was opened on: the list may move
  /// before a choice is made.
  void openMissingPlayModal(HistoryPlayRow row, {required bool viaKeyboard}) {
    openHistoryMissingPlayModal(
      context,
      path: row.path,
      extras: playExtras(row),
      viaKeyboard: viaKeyboard,
    );
  }
}
