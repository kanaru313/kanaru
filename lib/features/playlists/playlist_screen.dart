import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_rows.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/library_loading.dart';
import 'playlist_entries_view.dart';
import 'playlist_page_actions.dart';
import 'playlist_page_data.dart';
import 'playlist_routes.dart';
import 'playlist_screen_states.dart';

final _log = Logger('playlists');

/// One playlist at `/playlists/:id`: header, then its entries. [routeId] is
/// the URL text; a malformed id or a playlist that is gone shows "not found".
class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({super.key, required this.routeId});

  final String routeId;

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  /// The last page shown, kept for a page that is on its way out.
  PlaylistPage? _lastPage;

  Widget _data(PlaylistPage? page) {
    if (page != null) {
      _lastPage = page;
      return _PlaylistBody(page);
    }
    // Deleting a playlist leaves its page first, but the page stays on screen
    // until its exit animation ends. Meanwhile the delete empties the query;
    // "not found" would flash on a page that is already leaving.
    final last = _lastPage;
    if (last != null && ModalRoute.of(context)?.isActive == false) {
      return _PlaylistBody(last);
    }
    return const PlaylistNotFound();
  }

  @override
  Widget build(BuildContext context) {
    final id = parsePlaylistRouteId(widget.routeId);
    final Widget body;
    if (ref.watch(libraryDatabaseProvider) == null) {
      body = const PlaylistsUnavailable();
    } else if (id == null) {
      body = const PlaylistNotFound();
    } else {
      ref.listen(playlistPageProvider(id), (previous, next) {
        if (next.hasError && !(previous?.hasError ?? false)) {
          _log.severe(
            'Reading the playlist failed',
            next.error,
            next.stackTrace,
          );
        }
      });
      body = ref
          .watch(playlistPageProvider(id))
          .when(
            // A reload after an edit keeps showing the page until the new
            // one arrives.
            skipLoadingOnReload: true,
            skipError: true,
            loading: () => const LibraryLoading(),
            error: (error, stack) => const PlaylistsUnavailable(),
            data: _data,
          );
    }
    // A detail page in a branch needs its own Material for the ink of rows.
    return Material(type: MaterialType.transparency, child: body);
  }
}

class _PlaylistBody extends ConsumerWidget {
  const _PlaylistBody(this.page);

  final PlaylistPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = page.playlist;
    final covers = ref.watch(coverCacheDirectoryProvider);

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
        playlist.name,
      ),
      onEntryQueueAction: (entry, action) {
        final track = entry.track;
        if (track == null) return;
        enqueueLoaded(ref, context, action, [
          playlistTrack(track, covers),
        ], track.title);
      },
      onRename: () => renamePlaylistInteractively(ref, context, playlist),
      onDelete: () => deletePlaylistInteractively(ref, context, playlist),
    );
  }
}
