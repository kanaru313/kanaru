import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_queries.dart';
import '../../core/database/queue_history_queries.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/add_to_playlist/create_playlist_prompt.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'playlist_page_actions.dart' show playableTracks;

final _log = Logger('queue_history');

/// What the menu of a saved queue can do.
enum QueueSnapshotAction {
  play,
  shuffle,
  playNext,
  addToQueue,
  saveAsPlaylist,
  delete,
}

/// The name of a saved queue: when it was saved, in the user's language.
String queueSnapshotName(AppLocalizations l10n, int savedAt) {
  final when = DateTime.fromMillisecondsSinceEpoch(savedAt);
  return l10n.queueHistorySavedAt(when, when);
}

/// Carries out [action] on saved queue [id], saved at [savedAt]. What is
/// needed from the widget tree is captured before the first `await`;
/// failures are logged and reported in a snackbar, never thrown.
Future<void> runQueueSnapshotAction(
  WidgetRef ref,
  BuildContext context,
  QueueSnapshotAction action, {
  required int id,
  required int savedAt,
}) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final l10n = context.l10n;
  final covers = ref.read(coverCacheDirectoryProvider);
  final name = queueSnapshotName(l10n, savedAt);
  void say(String text) => messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(text)));

  try {
    switch (action) {
      case QueueSnapshotAction.delete:
        if (!await _confirmDelete(navigator.context, l10n)) return;
        await db.deleteQueueSnapshot(id);
        say(l10n.queueHistoryDeleted);
      case QueueSnapshotAction.saveAsPlaylist:
        final paths = await db.queueSnapshotPaths(id);
        if (paths.isEmpty || !navigator.mounted) return;
        final created = await promptAndCreatePlaylist(
          navigator.context,
          db,
          messenger,
          l10n,
          paths: paths,
          initialName: name,
        );
        if (created != null) {
          say(l10n.queueHistorySavedAsPlaylist(created.name));
        }
      case QueueSnapshotAction.play ||
          QueueSnapshotAction.shuffle ||
          QueueSnapshotAction.playNext ||
          QueueSnapshotAction.addToQueue:
        final page = await db.playlistPage(id);
        final tracks = playableTracks(page?.entries ?? const [], covers);
        if (tracks.isEmpty) {
          say(l10n.queueHistoryNothingToPlay);
          return;
        }
        switch (action) {
          case QueueSnapshotAction.play:
            playTracks(ref, tracks, 0);
          case QueueSnapshotAction.shuffle:
            shuffleTracks(ref, tracks);
          case _:
            await enqueueTracks(
              ref,
              messenger,
              l10n,
              action == QueueSnapshotAction.playNext
                  ? QueueAction.playNext
                  : QueueAction.addToQueue,
              () async => tracks,
              name,
            );
        }
    }
  } catch (error, stack) {
    _log.severe('A saved queue action failed', error, stack);
    say(l10n.libraryUnexpectedError);
  }
}

Future<bool> _confirmDelete(BuildContext context, AppLocalizations l10n) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.queueHistoryDeleteTitle),
      content: Text(l10n.queueHistoryDeleteMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.queueHistoryDelete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The rows of the saved queue menu.
List<PopupMenuEntry<QueueSnapshotAction>> queueSnapshotMenuItems(
  BuildContext context,
) {
  final l10n = context.l10n;
  return [
    menuRow(QueueSnapshotAction.play, AppIcons.play, l10n.queueHistoryPlay),
    menuRow(
      QueueSnapshotAction.shuffle,
      AppIcons.shuffle,
      l10n.queueHistoryShuffle,
    ),
    menuRow(
      QueueSnapshotAction.playNext,
      AppIcons.playlistPlay,
      l10n.queuePlayNext,
    ),
    menuRow(
      QueueSnapshotAction.addToQueue,
      AppIcons.addToQueue,
      l10n.queueAddToQueue,
    ),
    menuRow(
      QueueSnapshotAction.saveAsPlaylist,
      AppIcons.saveQueue,
      l10n.queueHistorySaveAsPlaylist,
    ),
    const PopupMenuDivider(),
    menuRow(
      QueueSnapshotAction.delete,
      AppIcons.deleteOutline,
      l10n.queueHistoryDelete,
    ),
  ];
}
