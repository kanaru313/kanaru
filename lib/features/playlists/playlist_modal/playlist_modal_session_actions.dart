import 'package:material_ui/material_ui.dart';

import '../../../core/database/playlist_modal_queries.dart';
import '../../../core/database/playlist_page_queries.dart';
import '../../../core/database/playlist_rows.dart';
import '../../../core/m3u/m3u_write.dart' show M3uPathStyle;
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/add_to_playlist/add_to_playlist_flow.dart';
import '../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../m3u_export_flow.dart';
import '../playlist_delete_dialog.dart';
import '../playlist_display_name.dart';
import '../playlist_edit_flow.dart';
import '../playlist_page_actions.dart';
import '../playlist_play_actions.dart';
import 'playlist_modal_session.dart';

/// The actions of the first page and the exports, each one reading the
/// opener's captured state through the session.
extension PlaylistModalSessionActions on PlaylistModalSession {
  Future<void> play(int id, {bool shuffle = false}) async {
    await ready();
    await playPlaylistIn(runner.container, id, shuffle: shuffle);
  }

  Future<void> addToPlaylist(PlaylistSummary latest) async {
    final db = this.db;
    final navigator = rootNavigator;
    if (db == null || navigator == null) return;
    final name = playlistDisplayName(latest, l10n);
    await addTracksToPlaylistWith(
      db: db,
      messenger: openerMessenger,
      l10n: l10n,
      dialogContext: navigator.context,
      // Every entry as stored, repeats and missing files included.
      readPaths: () async {
        await ready();
        return db.playlistEntryPaths(latest.id);
      },
      label: name,
      excludePlaylistId: latest.id,
      suggestedName: latest.isFavorites
          ? l10n.favoritesCopyDefaultName(DateTime.now())
          : name,
    );
  }

  Future<void> addAllToFavorites(PlaylistSummary latest) =>
      runner.addPathsToFavorites((db) async {
        await ready();
        // Library songs only: an entry without a file has nothing to like.
        return [
          for (final p in await db.playlistPlayableTracks(latest.id))
            p.track.path,
        ];
      }, playlistDisplayName(latest, l10n));

  Future<void> edit(
    PlaylistSummary latest,
    List<String> latestCoverKeys,
    ScaffoldMessengerState? modalMessenger,
  ) async {
    final db = this.db;
    final navigator = rootNavigator;
    if (db == null || navigator == null || !navigator.mounted) return;
    if (dialogOpen) return;
    dialogOpen = true;
    try {
      // The dialog goes above the modal route, which stays open under it.
      await editPlaylistWith(
        db: db,
        modalMessenger: modalMessenger,
        openerMessenger: openerMessenger,
        l10n: l10n,
        dialogContext: navigator.context,
        playlist: latest,
        coverKeys: latestCoverKeys,
      );
    } finally {
      dialogOpen = false;
    }
  }

  Future<void> delete(ContextModalNav nav, PlaylistSummary latest) async {
    final db = this.db;
    final navigator = rootNavigator;
    if (db == null || navigator == null || !navigator.mounted) return;
    if (dialogOpen) return;
    dialogOpen = true;
    final confirmed = await confirmDeletePlaylist(
      navigator.context,
      latest,
    ).whenComplete(() => dialogOpen = false);
    // Cancel, Esc and a tap outside come back to the modal.
    if (!confirmed) return;
    nav.close();
    await deletePlaylistWith(
      db: db,
      router: router,
      messenger: openerMessenger,
      l10n: l10n,
      playlist: latest,
    );
  }

  Future<void> export(PlaylistSummary latest, M3uPathStyle style) async {
    await ready();
    await exportPlaylistWith(
      save: save,
      db: db,
      messenger: openerMessenger,
      l10n: l10n,
      navigator: rootNavigator,
      playlist: latest,
      style: style,
    );
  }
}
