import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/library_loading.dart';
import 'm3u_export_flow.dart';
import 'playlist_entries_view.dart';
import 'playlist_page_actions.dart';
import 'playlist_page_data.dart';
import 'playlist_screen_states.dart';
import 'queue_history_actions.dart';
import 'queue_history_providers.dart';
import 'queue_history_routes.dart';

final _log = Logger('queue_history');

/// One saved queue at `/queue-history/:id`, shown with the playlist entries
/// view and named by when it was saved. Play, queue, export and editing the
/// entries work as on a playlist page; shuffle, save as playlist and delete
/// are in the menu of its row on the queue history page. An id that is not
/// a saved queue (an ordinary playlist, or gone) shows "not found".
class QueueHistorySnapshotScreen extends ConsumerStatefulWidget {
  const QueueHistorySnapshotScreen({super.key, required this.routeId});

  final String routeId;

  @override
  ConsumerState<QueueHistorySnapshotScreen> createState() =>
      _QueueHistorySnapshotScreenState();
}

class _QueueHistorySnapshotScreenState
    extends ConsumerState<QueueHistorySnapshotScreen> {
  /// The renamed page and what it was made from: the entries view tells new
  /// data by identity, so the same page must give the same renamed one.
  PlaylistPage? _source;
  String? _sourceName;
  PlaylistPage? _renamed;

  PlaylistPage _named(PlaylistPage page, String name) {
    if (identical(page, _source) && name == _sourceName) return _renamed!;
    final playlist = page.playlist;
    _source = page;
    _sourceName = name;
    return _renamed = PlaylistPage(
      playlist: PlaylistSummary(
        id: playlist.id,
        name: name,
        createdAt: playlist.createdAt,
        entryCount: playlist.entryCount,
      ),
      entries: page.entries,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = parseQueueHistoryRouteId(widget.routeId);
    final Widget body;
    if (ref.watch(libraryDatabaseProvider) == null) {
      body = const PlaylistsUnavailable();
    } else if (id == null) {
      body = const PlaylistNotFound();
    } else {
      body = _body(id);
    }
    // A detail page in a branch needs its own Material for the ink of rows.
    return Material(type: MaterialType.transparency, child: body);
  }

  Widget _body(int id) {
    ref.listen(playlistPageProvider(id), (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        _log.severe(
          'Reading a saved queue failed',
          next.error,
          next.stackTrace,
        );
      }
    });
    final savedAt = ref.watch(queueSnapshotSavedAtProvider(id));
    final page = ref.watch(playlistPageProvider(id));
    if (savedAt.hasError || page.hasError) return const PlaylistsUnavailable();
    if (!savedAt.hasValue || !page.hasValue) return const LibraryLoading();
    final when = savedAt.value;
    final loaded = page.value;
    if (when == null || loaded == null) return const PlaylistNotFound();
    return _SnapshotBody(_named(loaded, queueSnapshotName(context.l10n, when)));
  }
}

class _SnapshotBody extends ConsumerWidget {
  const _SnapshotBody(this.page);

  final PlaylistPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = page.playlist.id;
    final covers = ref.watch(coverCacheDirectoryProvider);
    final name = page.playlist.name;
    return PlaylistEntriesView(
      page: page,
      onMove: (entryId, to) =>
          movePlaylistEntryOrReport(ref, context, id, entryId, to),
      onRemove: (entryId) =>
          removePlaylistEntryOrReport(ref, context, id, entryId),
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
      onExport: (style) =>
          exportPlaylistInteractively(ref, context, page, style),
    );
  }
}
