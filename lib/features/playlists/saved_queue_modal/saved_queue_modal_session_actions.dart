import 'package:logging/logging.dart';

import '../../../core/database/playlist_writes.dart';
import '../../../core/database/playlist_modal_queries.dart';
import '../../../core/database/playlist_page_queries.dart';
import '../../../core/database/playlist_rows.dart';
import '../../../core/database/queue_history_queries.dart';
import '../../../core/m3u/m3u_write.dart' show M3uPathStyle;
import '../../../shared/m3u/m3u_save_picker.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../m3u_export_flow.dart';
import '../playlist_play_actions.dart';
import '../queue_history_routes.dart';
import 'saved_queue_modal_session.dart';

final _log = Logger('queue_history');

/// The actions of the saved-queue modal, each one reading the opener's
/// captured state through the session. None of them throws.
extension SavedQueueModalSessionActions on SavedQueueModalSession {
  Future<void> play(int id, {bool shuffle = false}) async {
    await ready();
    await playPlaylistIn(runner.container, id, shuffle: shuffle);
  }

  /// Copies every stored entry (repeats and missing files included) into the
  /// playlists the user picks; a new playlist is suggested under the queue's
  /// name.
  void addToPlaylist(PlaylistSummary latest) => runner.queueHost?.addToPlaylist(
    (db) async {
      await ready();
      return db.playlistEntryPaths(latest.id);
    },
    latest.name,
    excludePlaylistId: latest.id,
    suggestedName: latest.name,
  );

  Future<void> addAllToFavorites(PlaylistSummary latest) =>
      runner.addPathsToFavorites((db) async {
        await ready();
        // Library songs only: an entry without a file has nothing to like.
        return [
          for (final p in await db.playlistPlayableTracks(latest.id))
            p.track.path,
        ];
      }, latest.name);

  Future<void> export(PlaylistSummary latest, M3uPathStyle style) async {
    await ready();
    await exportPlaylistWith(
      save: runner.container.read(m3uSavePickerProvider),
      db: runner.db,
      messenger: runner.messenger,
      l10n: runner.l10n,
      navigator: runner.rootNavigator,
      playlist: latest,
      style: style,
    );
  }

  /// Delete queue: confirms above the modal (cancel comes back to it), then
  /// closes the modal, waits for the opener's writes and, on the queue's own
  /// page, leaves it for the Queues list before deleting, so the page never
  /// reloads to "not found".
  Future<void> deleteQueue(ContextModalNav nav, PlaylistSummary latest) async {
    final db = runner.db;
    final navigator = runner.rootNavigator;
    final l10n = runner.l10n;
    if (db == null || navigator == null || !navigator.mounted) return;
    if (dialogOpen) return;
    dialogOpen = true;
    final confirmed = await confirmAction(
      navigator.context,
      title: l10n.queueHistoryDeleteTitle,
      body: l10n.queueHistoryDeleteMessage,
      confirmLabel: l10n.queueHistoryDelete,
    ).whenComplete(() => dialogOpen = false);
    if (!confirmed) return;
    nav.close();
    await ready();
    try {
      if (!showGoTo) runner.goTo(queueHistoryPath);
      await db.deleteQueueSnapshot(latest.id);
      say(AppSnackBarKind.success, l10n.queueHistoryDeleted);
    } catch (error, stack) {
      _log.severe('Deleting saved queue ${latest.id} failed', error, stack);
      say(AppSnackBarKind.error, l10n.libraryUnexpectedError);
    }
  }

  /// Remove missing songs, which cannot be refilled by hand on a saved
  /// queue: confirms above the modal (cancel comes back to it), then closes
  /// the modal and removes.
  Future<void> confirmRemoveMissing(
    ContextModalNav nav,
    PlaylistSummary latest,
  ) async {
    final navigator = runner.rootNavigator;
    final l10n = runner.l10n;
    if (navigator == null || !navigator.mounted) return;
    if (dialogOpen) return;
    dialogOpen = true;
    final confirmed = await confirmAction(
      navigator.context,
      title: l10n.queueModalRemoveMissingTitle,
      body: l10n.queueModalRemoveMissingBody,
      confirmLabel: l10n.playlistRemoveMissing,
    ).whenComplete(() => dialogOpen = false);
    if (!confirmed) return;
    nav.close();
    await removeMissing(latest);
  }

  /// Deletes the entries whose file is not in the library. The ids are read
  /// now, at tap time, so only those go: a scan that adds the file back, or a
  /// new entry, between the count shown and this tap is never swept up.
  Future<void> removeMissing(PlaylistSummary latest) async {
    final db = runner.db;
    final l10n = runner.l10n;
    if (db == null) return;
    await ready();
    try {
      final ids = await db.playlistMissingEntryIds(latest.id);
      final removed = await db.removePlaylistEntries(latest.id, ids.toSet());
      if (removed > 0) {
        say(AppSnackBarKind.success, l10n.playlistMissingRemoved(removed));
      }
    } catch (error, stack) {
      _log.severe(
        'Removing missing songs of ${latest.id} failed',
        error,
        stack,
      );
      say(AppSnackBarKind.error, l10n.playlistSaveFailed);
    }
  }
}
