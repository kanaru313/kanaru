import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/library_rows.dart' show TrackListItem;
import '../../core/database/playlist_rows.dart';
import '../../core/database/playlist_writes.dart';
import '../../core/player/track.dart' as player;
import '../../l10n/l10n.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/add_to_playlist/playlist_name_dialog.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'playlist_delete_dialog.dart';
import 'playlist_routes.dart';

final _log = Logger('playlists');

/// The queue entry of one library track of a playlist.
player.Track playlistTrack(TrackListItem track, String? coverDir) =>
    trackFromListItem(track, coverDir);

/// Where a play queue built from [playable] starts: the entry [entryId]
/// when it is still there, otherwise the first playable entry stored at
/// [indexHint] or later (the tapped entry was removed meanwhile, and the
/// next song is the closest thing to what the user pointed at). Null when
/// nothing is left to play. A null [entryId] starts at the first playable
/// entry.
int? playableStartIndex(
  List<PlaylistPlayableTrack> playable,
  int? entryId,
  int indexHint,
) {
  if (entryId != null) {
    final exact = playable.indexWhere((p) => p.entryId == entryId);
    if (exact >= 0) return exact;
  }
  final next = playable.indexWhere((p) => p.position >= indexHint);
  return next < 0 ? null : next;
}

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

/// Removes entry [entryId] from playlist [playlistId]. Completes with
/// whether it was saved; a failure is logged and reported in a snackbar.
Future<bool> removePlaylistEntryOrReport(
  WidgetRef ref,
  BuildContext context,
  int playlistId,
  int entryId,
) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return false;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    await db.removePlaylistEntries(playlistId, {entryId});
    return true;
  } catch (error, stack) {
    _reportFailure(messenger, l10n, 'Removing a playlist entry', error, stack);
    return false;
  }
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
    messenger.showSnackBar(
      appSnackBar(kind: AppSnackBarKind.error, title: l10n.playlistSaveFailed),
    );
  } catch (snackError, snackStack) {
    _log.severe('Reporting the failure failed', snackError, snackStack);
  }
}
