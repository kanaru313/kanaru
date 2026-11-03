import 'dart:async';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart'
    show BuildContext, ValueChanged, VoidCallback;
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart' show ScaffoldMessengerState;

import '../../../../core/database/library_startup.dart';
import '../../../../core/indexer/excluded_folders_controller.dart';
import '../../../../shared/enqueue_from_database.dart';
import '../../../../shared/library_route_keys.dart';
import '../../../../shared/play_tracks.dart';
import '../../../../shared/queue_host.dart';
import '../../../../shared/root_rejection_message.dart';
import '../../../../shared/track_menu_actions.dart';
import '../../../../shared/widgets/add_to_playlist/create_playlist_prompt.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../../../../shared/widgets/queue_actions_menu.dart';
import '../folder_songs.dart';
import '../folder_tree.dart';

final _log = Logger('folders');

/// What one open folder modal holds: a snapshot of the folder and everything
/// its actions need from the widget tree, captured before the modal opened.
/// The tile may be rebuilt away while the modal is open, so nothing here
/// refers to the tile's own `BuildContext`.
class FolderModalSession {
  FolderModalSession({
    required this.folder,
    required this.runner,
    required this.onQueueAction,
    this.direct = false,
    this.showFolder = true,
    QueueHost? queueHost,
    this.dialogContext,
    this.messenger,
  }) : queueHost = queueHost ?? runner.queueHost;

  final FolderNode folder;
  final bool direct;
  final bool showFolder;
  final TrackMenuRunner runner;
  final QueueHost? queueHost;
  final ValueChanged<QueueAction> onQueueAction;
  final BuildContext? dialogContext;
  final ScaffoldMessengerState? messenger;

  /// Runs a queue action of the footer or Add to playlist.
  void queue(QueueAction action) =>
      QueueHost.run(queueHost, () => onQueueAction(action));

  /// Plays songs in the folder (in natural tree order or direct).
  Future<void> play({required bool recursive, bool shuffle = false}) =>
      playFromDatabaseIn(runner.container, 'Playing a folder failed', (
        db,
        covers,
      ) async {
        final songs = await readFolderSongs(
          db,
          folder.path,
          recursive: recursive,
        );
        return [for (final s in songs) trackFromRow(s, covers)];
      }, shuffle: shuffle);

  /// Prompts for a playlist name and creates a playlist from the folder's songs.
  Future<void> createPlaylist() async {
    final db = runner.container.read(libraryDatabaseProvider);
    if (db == null) return;
    final ctx = dialogContext;
    final msg = messenger;
    final l10n = runner.l10n;
    if (ctx == null || !ctx.mounted) return;
    try {
      final paths = [
        for (final t in await readFolderSongs(
          db,
          folder.path,
          recursive: !direct,
        ))
          t.path,
      ];
      if (paths.isEmpty) {
        msg?.showAppSnackBar(AppSnackBarKind.info, l10n.foldersEmptyFolder);
        return;
      }
      if (!ctx.mounted) return;
      final created = await promptAndCreatePlaylist(
        ctx,
        db,
        msg,
        l10n,
        paths: paths,
        initialName: folder.name,
      );
      if (created == null) return;
      msg?.showAppSnackBar(
        AppSnackBarKind.success,
        l10n.playlistAdded(folder.name, created.name),
      );
    } catch (error, stackTrace) {
      _log.severe(
        'Creating a playlist from a folder failed',
        error,
        stackTrace,
      );
      msg?.showAppSnackBar(AppSnackBarKind.error, l10n.libraryUnexpectedError);
    }
  }

  /// Copies the folder path to clipboard and reports in a snackbar.
  Future<void> copyPath() async {
    try {
      await Clipboard.setData(ClipboardData(text: folder.path));
      messenger?.showAppSnackBar(
        AppSnackBarKind.info,
        runner.l10n.folderModalPathCopied,
      );
    } catch (error, stackTrace) {
      _log.severe('Copying folder path failed', error, stackTrace);
      messenger?.showAppSnackBar(
        AppSnackBarKind.error,
        runner.l10n.libraryUnexpectedError,
      );
    }
  }

  /// Adds the folder to the excluded folders list and starts a rescan.
  Future<void> excludeFromLibrary() async {
    try {
      final controller = runner.container.read(
        excludedFoldersControllerProvider,
      );
      final result = await controller.add(folder.path);
      final rejection = result.rejection;
      final conflict = result.conflict;
      final l10n = runner.l10n;
      if (rejection != null) {
        messenger?.showAppSnackBar(
          AppSnackBarKind.warning,
          rootRejectionMessage(l10n, folder.path, rejection),
        );
      } else if (conflict != null) {
        messenger?.showAppSnackBar(AppSnackBarKind.warning, switch (conflict) {
          ExclusionConflict.sameAsRoot => l10n.excludedFoldersSameAsRoot,
          ExclusionConflict.outsideLibrary =>
            l10n.excludedFoldersOutsideLibrary,
          ExclusionConflict.alreadyExcluded =>
            l10n.excludedFoldersAlreadyExcluded,
        });
      }
    } catch (error, stackTrace) {
      _log.severe('Excluding folder failed', error, stackTrace);
      messenger?.showAppSnackBar(
        AppSnackBarKind.error,
        runner.l10n.libraryUnexpectedError,
      );
    }
  }

  /// The callbacks the actions call once the modal is closed.
  FolderModalHandlers handlers({
    void Function(ContextModalNav nav)? openAdvanced,
  }) => FolderModalHandlers(
    openAdvanced: openAdvanced,
    goToFolder: () => runner.goTo(folderLocation(folder.path)),
    playAll: () => unawaited(play(recursive: !direct)),
    shuffle: () => unawaited(play(recursive: !direct, shuffle: true)),
    playAllBelow: direct && folder.subfolders > 0
        ? () => unawaited(play(recursive: true))
        : null,
    addToPlaylist: () => queue(QueueAction.addToPlaylist),
    createPlaylist: () => unawaited(createPlaylist()),
    showInFileManager: (sample) =>
        unawaited(runner.showInFileManagerAt(sample ?? folder.path)),
    copyPath: () => unawaited(copyPath()),
    excludeFromLibrary: () => unawaited(excludeFromLibrary()),
  );
}

/// What the folder actions do. Each one runs after the modal has closed,
/// except [openAdvanced], which pushes the advanced page.
class FolderModalHandlers {
  const FolderModalHandlers({
    required this.goToFolder,
    required this.playAll,
    required this.shuffle,
    this.playAllBelow,
    required this.addToPlaylist,
    required this.createPlaylist,
    required this.showInFileManager,
    required this.copyPath,
    required this.excludeFromLibrary,
    this.openAdvanced,
  });

  final VoidCallback goToFolder;
  final VoidCallback playAll;
  final VoidCallback shuffle;

  /// In flat view, plays all songs below the folder when it has subfolders.
  final VoidCallback? playAllBelow;

  final VoidCallback addToPlaylist;
  final VoidCallback createPlaylist;

  /// Shows the folder (or sample file) in the native file manager.
  final ValueChanged<String?> showInFileManager;

  final VoidCallback copyPath;
  final VoidCallback excludeFromLibrary;
  final void Function(ContextModalNav nav)? openAdvanced;
}
