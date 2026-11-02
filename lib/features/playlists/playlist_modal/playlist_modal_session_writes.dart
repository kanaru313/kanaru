import 'package:logging/logging.dart';

import '../../../core/database/playlist_edit_writes.dart';
import '../../../core/database/playlist_modal_queries.dart';
import '../../../core/database/playlist_rows.dart';
import '../../../core/database/playlist_writes.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../playlist_display_name.dart';
import 'playlist_modal_session.dart';

final _log = Logger('playlists');

/// The writes of the Advanced page. Each one runs after the modal has
/// closed, waits for the opener's writes first, reports in the opener's
/// messenger and never throws.
extension PlaylistModalSessionWrites on PlaylistModalSession {
  /// Copies [latest] into a new playlist named "name (copy)", repeats
  /// included. No navigation.
  Future<void> duplicate(PlaylistSummary latest) async {
    final db = this.db;
    if (db == null) return;
    await ready();
    try {
      final name = l10n.playlistCopyName(playlistDisplayName(latest, l10n));
      final id = await db.duplicatePlaylist(
        latest.id,
        name: name,
        now: DateTime.now().millisecondsSinceEpoch,
      );
      say(
        id == null ? AppSnackBarKind.error : AppSnackBarKind.success,
        id == null ? l10n.playlistSaveFailed : l10n.playlistDuplicated(name),
      );
    } catch (error, stack) {
      _log.severe('Duplicating playlist ${latest.id} failed', error, stack);
      say(AppSnackBarKind.error, l10n.playlistSaveFailed);
    }
  }

  /// Deletes the extra copies of repeated songs, keeping the first of each.
  Future<void> removeRepeated(PlaylistSummary latest) async {
    final db = this.db;
    if (db == null) return;
    await ready();
    try {
      final removed = await db.removeRepeatedEntries(latest.id);
      if (removed > 0) {
        say(AppSnackBarKind.success, l10n.playlistDuplicatesRemoved(removed));
      }
    } catch (error, stack) {
      _log.severe('Removing repeats of ${latest.id} failed', error, stack);
      say(AppSnackBarKind.error, l10n.playlistSaveFailed);
    }
  }

  /// Deletes the entries whose file is not in the library. The ids are read
  /// now, at tap time, so only those go: a scan that adds the file back, or a
  /// new entry, between the count shown and this tap is never swept up.
  Future<void> removeMissing(PlaylistSummary latest) async {
    final db = this.db;
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
