import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/library_rows.dart' show TrackListItem;
import '../../core/database/playlist_rows.dart';
import '../../core/database/playlist_writes.dart';
import '../../core/indexer/cover_paths.dart';
import '../../core/player/track.dart' as player;
import '../../l10n/l10n.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/add_to_playlist/playlist_name_dialog.dart';
import 'playlist_delete_dialog.dart';
import 'playlist_routes.dart';

final _log = Logger('playlists');

/// The queue entries for [rows] whose file is in the library, in order.
/// [coverDir] is the cover cache directory (null when covers are off).
List<player.Track> playableTracks(
  List<PlaylistEntryRow> rows,
  String? coverDir,
) => [
  for (final row in rows)
    if (row.track case final track?) playlistTrack(track, coverDir),
];

/// The queue entry of one library track of a playlist.
player.Track playlistTrack(TrackListItem track, String? coverDir) =>
    trackFromItem(
      path: track.path,
      title: track.title,
      artist: track.artist,
      durationMs: track.durationMs,
      artPath: coverPath(coverDir, track.coverKey),
    );

/// Where `rows[index]` lands in [playableTracks] of the same rows: the
/// number of playable rows before it.
int playableIndex(List<PlaylistEntryRow> rows, int index) =>
    rows.take(index).where((row) => row.track != null).length;

/// Moves [entryId] of playlist [playlistId] to index [to]. Completes with
/// whether it was saved; a failure is logged and reported in a snackbar.
Future<bool> movePlaylistEntryOrReport(
  WidgetRef ref,
  BuildContext context,
  int playlistId,
  int entryId,
  int to,
) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return false;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    await db.movePlaylistEntry(playlistId, entryId, to);
    return true;
  } catch (error, stack) {
    _reportFailure(messenger, l10n, 'Moving a playlist entry', error, stack);
    return false;
  }
}

/// Removes entry [entryId] from playlist [playlistId]; a failure is logged
/// and reported in a snackbar.
void removePlaylistEntryOrReport(
  WidgetRef ref,
  BuildContext context,
  int playlistId,
  int entryId,
) {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  unawaited(
    db.removePlaylistEntries(playlistId, {entryId}).catchError((
      Object error,
      StackTrace stack,
    ) {
      _reportFailure(
        messenger,
        l10n,
        'Removing a playlist entry',
        error,
        stack,
      );
    }),
  );
}

/// Asks for a new name for [playlist] and saves it.
Future<void> renamePlaylistInteractively(
  WidgetRef ref,
  BuildContext context,
  PlaylistSummary playlist,
) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final name = await showPlaylistNameDialog(
    context,
    title: l10n.playlistRenameTitle,
    confirmLabel: l10n.playlistRename,
    initialName: playlist.name,
  );
  if (name == null || name == playlist.name) return;
  try {
    await db.renamePlaylist(playlist.id, name);
  } catch (error, stack) {
    _reportFailure(messenger, l10n, 'Renaming a playlist', error, stack);
  }
}

/// Asks to confirm, then leaves the page and deletes [playlist].
///
/// The page is left first: deleting first would reload the open page to
/// "not found" before the navigation. Everything the widget tree gives is
/// captured before the dialog, because the page may be gone after it.
Future<void> deletePlaylistInteractively(
  WidgetRef ref,
  BuildContext context,
  PlaylistSummary playlist,
) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final l10n = context.l10n;
  if (!await confirmDeletePlaylist(context, playlist)) return;
  router.go(playlistsPath);
  try {
    await db.deletePlaylist(playlist.id);
  } catch (error, stack) {
    _reportFailure(messenger, l10n, 'Deleting a playlist', error, stack);
  }
}

void _reportFailure(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  String what,
  Object error,
  StackTrace stack,
) {
  _log.severe('$what failed', error, stack);
  try {
    messenger.showSnackBar(SnackBar(content: Text(l10n.playlistSaveFailed)));
  } catch (snackError, snackStack) {
    _log.severe('Reporting the failure failed', snackError, snackStack);
  }
}
