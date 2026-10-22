import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/database/playlist_writes.dart';
import '../../../l10n/l10n.dart';
import 'add_to_playlist_dialog.dart';
import 'create_playlist_prompt.dart';

final _log = Logger('playlists');

/// Asks which playlist, reads [readPaths], adds the songs the playlist does
/// not hold yet and says how many were added and how many were already
/// there, naming [label]. Nothing asks about duplicates.
///
/// Everything from the widget tree is captured before the first `await`:
/// the row that opened the menu can be rebuilt away by a rescan while the
/// picker is open. Failures are logged and reported in a snackbar, never
/// thrown to the caller.
Future<void> addTracksToPlaylist(
  WidgetRef ref,
  BuildContext context,
  Future<List<String>> Function() readPaths,
  String label,
) async {
  if (!context.mounted) return;
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  // The root navigator outlives the page, and sits above Now Playing.
  final dialogContext = Navigator.of(context, rootNavigator: true).context;

  final pick = await showAddToPlaylistDialog(dialogContext);
  if (pick == null) return;

  String text;
  try {
    final paths = await readPaths();
    // The album or artist vanished in a rescan: nothing to add.
    if (paths.isEmpty) return;
    switch (pick) {
      case PickedNewPlaylist():
        if (!dialogContext.mounted) return;
        // Repeats inside the batch collapse; the first occurrence stays.
        final created = await promptAndCreatePlaylist(
          dialogContext,
          db,
          messenger,
          l10n,
          paths: paths.toSet().toList(),
        );
        if (created == null) return;
        text = l10n.playlistAdded(label, created.name);
      case PickedPlaylist(:final playlist):
        final (:added, :skipped) = await db.addMissingToPlaylist(
          playlist.id,
          paths,
        );
        text = added == 0
            ? l10n.playlistAlreadyIn(label, playlist.name)
            : skipped == 0
            ? l10n.playlistAdded(label, playlist.name)
            : l10n.playlistAddedSkipped(added, skipped, playlist.name);
    }
  } catch (error, stack) {
    _log.severe('Adding to a playlist failed', error, stack);
    text = l10n.playlistSaveFailed;
  }
  // The songs are saved: failing to say so is no saving failure.
  try {
    messenger.showSnackBar(SnackBar(content: Text(text)));
  } catch (error, stack) {
    _log.warning('Showing the playlist message failed', error, stack);
  }
}
