import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import 'playlist_display_name.dart';
import 'playlist_entries_view.dart';
import 'playlist_page_actions.dart';

/// The body of a playlist page, shared by `/playlists/:id` and
/// `/favorites`: play, reorder, remove and queue. The Favorites
/// playlist has no rename or delete; removing one of its rows unlikes the
/// song.
class PlaylistPageBody extends ConsumerWidget {
  const PlaylistPageBody(this.page, {super.key});

  final PlaylistPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = page.playlist;
    final covers = ref.watch(coverCacheDirectoryProvider);
    final name = playlistDisplayName(playlist, context.l10n);

    return PlaylistEntriesView(
      page: page,
      onMove: (entryId, to) =>
          movePlaylistEntryOrReport(ref, context, playlist.id, entryId, to),
      onRemove: (entryId) =>
          removePlaylistEntryOrReport(ref, context, playlist.id, entryId),
      onPlayFrom: (shown, index) => playTracks(
        ref,
        playableTracks(shown, covers),
        playableIndex(shown, index),
      ),
      onQueueAction: (shown, action) => enqueueLoaded(
        ref,
        context,
        action,
        playableTracks(shown, covers),
        name,
      ),
      onEntryQueueAction: (entry, action) {
        final track = entry.track;
        if (track == null) return;
        enqueueLoaded(ref, context, action, [
          playlistTrack(track, covers),
        ], track.title);
      },
      onRename: playlist.isFavorites
          ? null
          : () => renamePlaylistInteractively(ref, context, playlist),
      onDelete: playlist.isFavorites
          ? null
          : () => deletePlaylistInteractively(ref, context, playlist),
    );
  }
}
