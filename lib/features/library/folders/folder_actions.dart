import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/track.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/enqueue_chain.dart';
import '../../../shared/enqueue_from_database.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import 'folder_songs.dart';
import 'folder_tree.dart';

final _log = Logger('library');

/// Enqueues the songs of [folder] into the queue or playlist.
void enqueueFolder(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  FolderNode folder, {
  bool recursive = true,
}) =>
    enqueueFromDatabase(ref, context, action, folder.name, (db, covers) async {
      return [
        for (final t in await readFolderSongs(
          db,
          folder.path,
          recursive: recursive,
        ))
          trackFromRow(t, covers),
      ];
    });

/// Replaces the queue with the songs of [folder], in order or shuffled.
Future<void> playFolder(
  WidgetRef ref,
  BuildContext context,
  FolderNode folder, {
  bool shuffle = false,
  bool recursive = true,
}) async {
  if (!context.mounted) return;
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final covers = ref.read(coverCacheDirectoryProvider);
  final player = ref.read(playerServiceProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    // Picks made before the tap finish first, so they cannot be taken for a
    // newer action by the check below.
    await pendingQueuePicks(ref);
    final changesBefore = player.userQueueChanges;
    final songs = await readFolderSongs(db, folder.path, recursive: recursive);
    // A queue opened or filled meanwhile came from a newer action: that one
    // wins over a read started before it.
    if (songs.isEmpty || player.userQueueChanges != changesBefore) return;
    final tracks = <Track>[for (final s in songs) trackFromRow(s, covers)];
    // Not guarded by `mounted`: leaving the page does not cancel the tap.
    unawaited(
      shuffle ? player.openShuffled(tracks) : player.openTracks(tracks),
    );
  } catch (error, stackTrace) {
    _log.severe('Reading the folder songs failed', error, stackTrace);
    messenger.showSnackBar(
      appSnackBar(
        kind: AppSnackBarKind.error,
        title: l10n.libraryUnexpectedError,
      ),
    );
  }
}
