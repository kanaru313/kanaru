import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_page_queries.dart';
import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'm3u_export_flow.dart';
import 'playlist_display_name.dart';
import 'playlist_entries_view.dart';
import 'playlist_page_actions.dart';
import 'playlist_page_data.dart';

final _log = Logger('playlists');

/// The body of a playlist page, shared by `/playlists/:id` and
/// `/favorites`: play, reorder, remove, queue and export as M3U. The Favorites
/// playlist has no rename or delete; removing one of its rows unlikes the
/// song.
///
/// The entries are read a window at a time by [PlaylistEntriesView]; the play
/// queue is read from the database when the user asks for it.
class PlaylistPageBody extends ConsumerStatefulWidget {
  const PlaylistPageBody(this.head, {super.key, required this.headSeq});

  final PlaylistPageHead head;

  /// `PlaylistHeadLoad.seq` of [head].
  final int headSeq;

  @override
  ConsumerState<PlaylistPageBody> createState() => _PlaylistPageBodyState();
}

class _PlaylistPageBodyState extends ConsumerState<PlaylistPageBody> {
  int get _id => widget.head.playlist.id;

  Future<List<PlaylistPositionedEntry>> _loadRows(int start, int count) async {
    final db = ref.read(libraryDatabaseProvider);
    return db == null ? const [] : db.playlistEntriesAt(_id, start, count);
  }

  /// Reads the playable tracks and opens them as the queue, starting at the
  /// entry [entryId] (see [playableStartIndex]). Leaving the page before the
  /// read ends plays nothing.
  Future<void> _playFrom(int? entryId, int indexHint) async {
    // Everything the widget tree gives is taken before the first await: the
    // page may be gone when the read ends.
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    final covers = ref.read(coverCacheDirectoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final playable = await db.playlistPlayableTracks(_id);
      if (!mounted) return;
      final start = playableStartIndex(playable, entryId, indexHint);
      if (start == null) return;
      playTracks(ref, [
        for (final p in playable) playlistTrack(p.track, covers),
      ], start);
    } catch (error, stack) {
      _log.severe('Reading the play queue failed', error, stack);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.libraryUnexpectedError)),
        );
      }
    }
  }

  /// A queue menu pick of the header: every playable song of the playlist,
  /// read when the pick's turn comes.
  void _queueAll(QueueAction action) {
    final playlist = widget.head.playlist;
    enqueueFromDatabase(
      ref,
      context,
      action,
      playlistDisplayName(playlist, context.l10n),
      (db, covers) async => [
        for (final p in await db.playlistPlayableTracks(playlist.id))
          playlistTrack(p.track, covers),
      ],
    );
  }

  int _settled() {
    // Taken before the reload starts: a head with a lower number was read
    // before the writes ended.
    final minSeq = nextPlaylistHeadSeq();
    ref.invalidate(playlistPageHeadProvider(_id));
    return minSeq;
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.head.playlist;
    final covers = ref.watch(coverCacheDirectoryProvider);

    return PlaylistEntriesView(
      // Another playlist is another list: its rows must not be reused.
      key: ValueKey(playlist.id),
      head: widget.head,
      headSeq: widget.headSeq,
      loadRows: _loadRows,
      onMove: (entryId, to) =>
          movePlaylistEntryOrReport(ref, context, playlist.id, entryId, to),
      onRemove: (entryId) =>
          removePlaylistEntryOrReport(ref, context, playlist.id, entryId),
      onSettled: _settled,
      onPlayFrom: _playFrom,
      onQueueAction: _queueAll,
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
      onExport: (style) =>
          exportPlaylistInteractively(ref, context, playlist, style),
    );
  }
}
