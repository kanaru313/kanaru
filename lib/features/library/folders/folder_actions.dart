import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/track.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/enqueue_tracks.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/widgets/add_to_playlist/create_playlist_prompt.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import 'folder_menu.dart';
import 'folder_songs.dart';
import 'folder_tree.dart';
import '../../../shared/widgets/app_snack_bar.dart';

final _log = Logger('library');

/// Runs [action] on the songs of [folder], read from the database when it
/// runs, in natural order of their paths: everything below it when
/// [recursive], else only the songs directly in it. [FolderAction.playAllBelow]
/// is always recursive.
void runFolderAction(
  WidgetRef ref,
  BuildContext context,
  FolderAction action,
  FolderNode folder, {
  bool recursive = true,
}) {
  switch (action) {
    case FolderAction.play:
      unawaited(
        _open(ref, context, folder, shuffle: false, recursive: recursive),
      );
    case FolderAction.playAllBelow:
      unawaited(_open(ref, context, folder, shuffle: false, recursive: true));
    case FolderAction.shuffle:
      unawaited(
        _open(ref, context, folder, shuffle: true, recursive: recursive),
      );
    case FolderAction.playNext:
      _enqueue(ref, context, QueueAction.playNext, folder, recursive);
    case FolderAction.addToQueue:
      _enqueue(ref, context, QueueAction.addToQueue, folder, recursive);
    case FolderAction.addToPlaylist:
      _enqueue(ref, context, QueueAction.addToPlaylist, folder, recursive);
    case FolderAction.createPlaylist:
      unawaited(_createPlaylist(ref, context, folder, recursive));
  }
}

void _enqueue(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  FolderNode folder,
  bool recursive,
) => enqueueFromDatabase(ref, context, action, folder.name, (db, covers) async {
  return [
    for (final t in await readFolderSongs(
      db,
      folder.path,
      recursive: recursive,
    ))
      trackFromListItem(t, covers),
  ];
});

/// Replaces the queue with the songs of [folder], in order or shuffled.
Future<void> _open(
  WidgetRef ref,
  BuildContext context,
  FolderNode folder, {
  required bool shuffle,
  required bool recursive,
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
    final tracks = <Track>[for (final s in songs) trackFromListItem(s, covers)];
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

/// Asks for a name (the folder's) and makes a playlist of the songs of
/// [folder]. They are read first, as the playlist is created with them in one
/// transaction once the name is confirmed; no songs, no dialog.
Future<void> _createPlaylist(
  WidgetRef ref,
  BuildContext context,
  FolderNode folder,
  bool recursive,
) async {
  if (!context.mounted) return;
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  // The root navigator outlives the page, and sits above Now Playing.
  final dialogContext = Navigator.of(context, rootNavigator: true).context;
  try {
    final paths = [
      for (final t in await readFolderSongs(
        db,
        folder.path,
        recursive: recursive,
      ))
        t.path,
    ];
    if (paths.isEmpty) {
      messenger.showSnackBar(
        appSnackBar(kind: AppSnackBarKind.info, title: l10n.foldersEmptyFolder),
      );
      return;
    }
    if (!dialogContext.mounted) return;
    final created = await promptAndCreatePlaylist(
      dialogContext,
      db,
      messenger,
      l10n,
      paths: paths,
      initialName: folder.name,
    );
    if (created == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.success,
          title: l10n.playlistAdded(folder.name, created.name),
        ),
      );
  } catch (error, stackTrace) {
    _log.severe('Creating a playlist from a folder failed', error, stackTrace);
    messenger.showSnackBar(
      appSnackBar(
        kind: AppSnackBarKind.error,
        title: l10n.libraryUnexpectedError,
      ),
    );
  }
}
