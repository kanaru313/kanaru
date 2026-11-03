import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/song_modal/song_modal_extras.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'history_day_queue.dart';
import 'history_missing_play_modal.dart';
import 'history_play_row_tile.dart';
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

  /// Song history, Remove from history and the played chip for the modal of
  /// [row], built when the modal opens.
  SongModalExtras playExtras(HistoryPlayRow row) => historyPlayExtras(
    context: context,
    ref: ref,
    path: row.path,
    location: historyTrackLocation,
    playId: row.id,
    headerNote: context.l10n.historyPlayedChip(
      historyPlayedText(context, row.playedAt),
    ),
  );

  /// Opens the Missing-play modal of [row], a play with no song in the
  /// library. The play is the one the modal was opened on: the list may move
  /// before a choice is made.
  void openMissingPlayModal(HistoryPlayRow row, {required bool viaKeyboard}) {
    final chip = context.l10n.historyPlayedChip(
      historyPlayedText(context, row.playedAt),
    );
    openHistoryMissingPlayModal(
      context,
      path: row.path,
      chip: chip,
      extras: playExtras(row),
      viaKeyboard: viaKeyboard,
    );
  }
}
