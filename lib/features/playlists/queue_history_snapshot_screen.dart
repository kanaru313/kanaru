import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/library_loading.dart';
import 'playlist_page_body.dart';
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
  /// The renamed head and what it was made from: the entries view tells new
  /// data by identity, so the same head must give the same renamed one.
  PlaylistPageHead? _source;
  String? _sourceName;
  PlaylistPageHead? _renamed;

  PlaylistPageHead _named(PlaylistPageHead head, String name) {
    if (identical(head, _source) && name == _sourceName) return _renamed!;
    final playlist = head.playlist;
    _source = head;
    _sourceName = name;
    return _renamed = PlaylistPageHead(
      playlist: PlaylistSummary(
        id: playlist.id,
        name: name,
        createdAt: playlist.createdAt,
        entryCount: playlist.entryCount,
      ),
      coverKeys: head.coverKeys,
      hasPlayable: head.hasPlayable,
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
    ref.listen(playlistPageHeadProvider(id), (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        _log.severe(
          'Reading a saved queue failed',
          next.error,
          next.stackTrace,
        );
      }
    });
    final savedAt = ref.watch(queueSnapshotSavedAtProvider(id));
    final load = ref.watch(playlistPageHeadProvider(id));
    if (savedAt.hasError || load.hasError) return const PlaylistsUnavailable();
    if (!savedAt.hasValue || !load.hasValue) return const LibraryLoading();
    final when = savedAt.value;
    final head = load.value!.head;
    if (when == null || head == null) return const PlaylistNotFound();
    // Play, queue, export and editing the entries as on a playlist page;
    // rename and delete are not offered (see the class comment).
    return PlaylistPageBody(
      _named(head, queueSnapshotName(context.l10n, when)),
      headSeq: load.value!.seq,
      canRenameAndDelete: false,
    );
  }
}
