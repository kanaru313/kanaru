import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_rows.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/enqueue_chain.dart';
import '../../../shared/song_modal/open_song_modal.dart';
import '../../../shared/song_modal/song_modal_data.dart';
import '../../../shared/song_modal/song_modal_extras.dart';
import '../../../shared/widgets/context_modal/context_modal_route.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import 'queue_tile_menu_actions.dart';

/// Opens the song modal for the queue row [target] was captured for, on the
/// library row [item] of its song.
///
/// The queue's own action, Remove from queue, is the first extras row (red).
/// The footer's Play next puts a copy behind the play next block (the row
/// stays, so it works on the playing row too), Add to queue appends a copy,
/// Add to playlist runs the playlist flow. Every action goes through
/// [target], which checks the queue again when the action runs, so a queue
/// changed while the modal was open is left alone.
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
      unawaited(target.copyToPlayNext());
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
