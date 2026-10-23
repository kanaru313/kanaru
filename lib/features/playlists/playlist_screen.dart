import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../shared/widgets/library_loading.dart';
import 'playlist_page_body.dart';
import 'playlist_page_data.dart';
import 'playlist_routes.dart';
import 'playlist_screen_states.dart';

final _log = Logger('playlists');

/// One playlist at `/playlists/:id`: header, then its entries. The Favorites
/// playlist shows here as on `/favorites` (no redirect). [routeId] is
/// the URL text; a malformed id or a playlist that is gone shows "not found".
class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({super.key, required this.routeId});

  final String routeId;

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  /// The last head shown, kept for a page that is on its way out.
  PlaylistHeadLoad? _lastLoad;

  Widget _data(PlaylistHeadLoad load) {
    final head = load.head;
    if (head != null) {
      _lastLoad = load;
      return PlaylistPageBody(head, headSeq: load.seq);
    }
    // Deleting a playlist leaves its page first, but the page stays on screen
    // until its exit animation ends. Meanwhile the delete empties the query;
    // "not found" would flash on a page that is already leaving.
    final last = _lastLoad;
    final lastHead = last?.head;
    if (last != null &&
        lastHead != null &&
        ModalRoute.of(context)?.isActive == false) {
      return PlaylistPageBody(lastHead, headSeq: last.seq);
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
      ref.listen(playlistPageHeadProvider(id), (previous, next) {
        if (next.hasError && !(previous?.hasError ?? false)) {
          _log.severe(
            'Reading the playlist failed',
            next.error,
            next.stackTrace,
          );
        }
      });
      body = ref
          .watch(playlistPageHeadProvider(id))
          .when(
            // A reload after an edit keeps showing the page until the new
            // head arrives.
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
