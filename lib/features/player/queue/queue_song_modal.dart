import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_rows.dart';
import '../../../core/player/player_service.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/enqueue_chain.dart';
import '../../../shared/song_modal/open_song_modal.dart';
import '../../../shared/song_modal/song_modal_data.dart';
import '../../../shared/song_modal/song_modal_extras.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/context_modal/context_modal_route.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import 'queue_tile.dart' show isUpNextRow;
import 'queue_tile_menu_actions.dart';

/// Opens the song modal for the queue row [target] was captured for, on the
/// library row [item] of its song.
///
/// The queue's own action, Remove from queue, is the first extras row (red).
/// The footer's Play next moves the row behind the play next block (never a
/// copy), Add to queue appends a copy, Add to playlist runs the playlist
/// flow. Every action goes through [target], which checks the queue again
/// when the action runs, so a queue changed while the modal was open is left
/// alone.
void openQueueSongModal(
  BuildContext context,
  WidgetRef ref, {
  required QueueRowMenuTarget target,
  required TrackListItem item,
  bool viaKeyboard = false,
}) {
  final l10n = target.l10n;
  openSongModal(
    context,
    ref,
    song: item,
    viaKeyboard: viaKeyboard,
    onQueueAction: (action) => _runQueueAction(target, action),
    extras: SongModalExtras(
      actions: [
        ContextModalAction(
          id: 'queue-remove',
          icon: AppIcons.playlistRemove,
          label: l10n.queueRemove,
          destructive: true,
          onTap: songModalCloseThen(
            () => unawaited(target.run(QueueRowChoice.remove)),
          ),
        ),
      ],
    ),
  );
}

void _runQueueAction(QueueRowMenuTarget target, QueueAction action) {
  switch (action) {
    case QueueAction.playNext:
      unawaited(_playNext(target));
    case QueueAction.addToQueue:
      // Without a messenger (no Scaffold above the row) nothing could report
      // the result, so nothing is added.
      final messenger = target.messenger;
      if (messenger == null) return;
      unawaited(
        enqueueTracksIn(
          target.container,
          messenger,
          target.l10n,
          QueueAction.addToQueue,
          () async => [target.track],
          target.track.title,
        ),
      );
    case QueueAction.addToPlaylist:
      unawaited(target.run(QueueRowChoice.addToPlaylist));
  }
}

/// Moves the row behind the play next block, unless it is the playing row or
/// already in that block: the queue would not change, so say so.
Future<void> _playNext(QueueRowMenuTarget target) async {
  final at = target.livePosition();
  if (at == null) {
    target.say(AppSnackBarKind.info, target.l10n.queueMenuStale);
    return;
  }
  final queue = target.container.read(playerServiceProvider).queue;
  final upNextRun = target.container
      .read(playerServiceProvider.notifier)
      .upNextRun;
  if (at == queue.index || isUpNextRow(queue, at, upNextRun)) {
    target.say(AppSnackBarKind.info, target.l10n.queueAlreadyUpNext);
    return;
  }
  await target.run(QueueRowChoice.playNext);
}
