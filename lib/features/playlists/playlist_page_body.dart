import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_page_queries.dart';
import '../../core/database/playlist_rows.dart';
import '../../core/database/search_playlist_queries.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import 'm3u_export_flow.dart';
import 'playlist_entries_view.dart';
import 'playlist_page_actions.dart';
import 'playlist_page_data.dart';
import 'playlist_play_actions.dart';

/// The body of a playlist page, shared by `/playlists/:id` and
/// `/favorites`: play, reorder, remove and queue; the header opens the
/// playlist modal. Removing a row of the Favorites playlist unlikes the song.
///
/// The entries are read a window at a time by [PlaylistEntriesView]; the play
/// queue is read from the database when the user asks for it.
class PlaylistPageBody extends ConsumerStatefulWidget {
  const PlaylistPageBody(
    this.head, {
    super.key,
    required this.headSeq,
    this.savedQueue = false,
  });

  final PlaylistPageHead head;

  /// A saved queue: the header keeps a popup menu (export and queue rows)
  /// instead of the playlist modal.
  final bool savedQueue;

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

  Future<PlaylistMatches> _loadMatches(List<String> terms) async {
    final db = ref.read(libraryDatabaseProvider);
    return db == null
        ? PlaylistMatches.empty
        : db.playlistEntriesMatching(_id, terms);
  }

  /// Opens the filtered rows (those with a song in the library) as the queue.
  void _playRows(List<PlaylistEntryRow> rows, int index) {
    if (index < 0 || index >= rows.length || rows[index].track == null) return;
    final covers = ref.read(coverCacheDirectoryProvider);
    // The index among the playable rows: rows without a song are not queued.
    final start = rows.take(index).where((r) => r.track != null).length;
    final tracks = [
      for (final row in rows)
        if (row.track case final track?) playlistTrack(track, covers),
    ];
    playTracks(ref, tracks, start);
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
      onMove: (entryId, to) => movePlaylistEntryOrReport(
        ref,
        context,
        playlist.id,
        entryId,
        to,
        savedQueue: widget.savedQueue,
      ),
      // Favorites unlike through the row heart, not a remove button.
      onRemove: playlist.isFavorites
          ? null
          : (entryId) => removePlaylistEntryOrReport(
              ref,
              context,
              playlist.id,
              entryId,
              savedQueue: widget.savedQueue,
            ),
      onSettled: _settled,
      onPlayFrom: (entryId, indexHint) => playPlaylistFrom(
        ref,
        context,
        () => mounted,
        _id,
        entryId,
        indexHint,
      ),
      onShuffle: () => shufflePlaylist(ref, context, () => mounted, _id),
      loadMatches: _loadMatches,
      onPlayRows: (rows, index) async => _playRows(rows, index),
      onQueueAction: (action) => queuePlaylist(ref, context, action, playlist),
      onEntryQueueAction: (entry, action) {
        final track = entry.track;
        if (track == null) return;
        enqueueLoaded(
          ref,
          context,
          action,
          [playlistTrack(track, covers)],
          track.title,
          excludePlaylistId: playlist.id,
        );
      },
      onExport: (style) =>
          exportPlaylistInteractively(ref, context, playlist, style),
      savedQueue: widget.savedQueue,
    );
  }
}
