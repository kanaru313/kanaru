import 'dart:async';

import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../core/database/search_playlist_queries.dart';
import '../../core/m3u/m3u_write.dart' show M3uPathStyle;
import '../../shared/in_page_filter.dart';
import '../../shared/in_page_filter_host.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'playlist_drag_tracking.dart';
import 'playlist_entry_placeholder.dart';
import 'playlist_entry_tile.dart';
import 'playlist_page_layout.dart';
import 'playlist_row_cache.dart';
import 'playlist_write_gate.dart';

/// A playlist page: header, then its entries as a list the user can
/// reorder by dragging a handle.
///
/// The list has one slot per entry but reads rows only for the slots that
/// come into view, a page at a time (see [PlaylistRowCache]); a slot shows a
/// placeholder until its row arrives. A dropped or removed row is edited in
/// the cache at once and stays that way while [onMove] / [onRemove] run;
/// when the last write ends the view tells [onSettled], takes the next head
/// that was read after that and reads the visible rows again, so the screen
/// goes back to what the database holds if a write failed.
class PlaylistEntriesView extends StatefulWidget {
  const PlaylistEntriesView({
    super.key,
    required this.head,
    this.headSeq = 0,
    required this.loadRows,
    required this.onPlayFrom,
    this.onShuffle,
    this.onMove,
    this.onRemove,
    this.onSettled,
    this.onQueueAction,
    this.onEntryQueueAction,
    this.onRename,
    this.onDelete,
    this.onExport,
    this.loadMatches,
    this.onPlayRows,
  }) : assert(
         (onMove == null && onRemove == null) || onSettled != null,
         'onSettled is needed with onMove or onRemove: without it the rows '
         'of a failed write are never read back',
       );

  /// The header data. A new object (not an equal one) is a new read of the
  /// playlist: the view takes its count and reads the visible rows again.
  final PlaylistPageHead head;

  /// Order of [head] among the reads of this playlist, from
  /// `PlaylistHeadLoad.seq`. Heads below the number [onSettled] last returned
  /// are ignored.
  final int headSeq;

  /// Reads the entries at positions `start` up to `start + count`.
  final PlaylistPageLoader loadRows;

  /// Plays the playlist as a queue starting at the entry [entryId], or at
  /// the first song that can play when it is null. [indexHint] is where the
  /// entry was in the list: the fallback when the entry is gone by the time
  /// the queue is read. Called after the writes under way have ended.
  final Future<void> Function(int? entryId, int indexHint) onPlayFrom;

  /// Shuffles the playable songs of the playlist as the queue; called after
  /// the writes under way have ended.
  final Future<void> Function()? onShuffle;

  /// Moves [entryId] so it ends up at index [to] of the list; completes with
  /// whether the move was saved. A throw counts as not saved. Drops are
  /// ignored while a write is running. Null: rows cannot be dragged.
  final Future<bool> Function(int entryId, int to)? onMove;

  /// Removes the entry with this id; completes with whether it was saved.
  /// Null: rows have no remove button.
  final Future<bool> Function(int entryId)? onRemove;

  /// Called when the last of the writes has ended, with the view still
  /// mounted. Reloads the head and returns the lowest `seq` the view may
  /// accept for it (`nextPlaylistHeadSeq()` from before the reload starts).
  /// Required with [onMove] or [onRemove]: the head it reloads is what puts
  /// the rows back when a write failed.
  final int Function()? onSettled;

  /// Queue menu of the header, for the whole playlist; called after the
  /// writes under way have ended.
  final void Function(QueueAction action)? onQueueAction;

  /// Queue menu of one row.
  final void Function(PlaylistEntryRow entry, QueueAction action)?
  onEntryQueueAction;

  /// Null leaves the item out of the header menu (the Favorites playlist).
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  /// Export items of the header menu; null leaves them out.
  final ValueChanged<M3uPathStyle>? onExport;

  /// Reads the entries whose song matches the filter terms. Null: the page
  /// has no filter box.
  final Future<PlaylistMatches> Function(List<String> terms)? loadMatches;

  /// Plays the filtered [rows] as the queue, from row `index`; called after
  /// the writes under way have ended. Needed with [loadMatches].
  final Future<void> Function(List<PlaylistEntryRow> rows, int index)?
  onPlayRows;

  @override
  State<PlaylistEntriesView> createState() => _PlaylistEntriesViewState();
}

final _log = Logger('playlists');

class _PlaylistEntriesViewState extends State<PlaylistEntriesView>
    with
        InPageFilterHost<PlaylistEntriesView>,
        PlaylistDragTracking<PlaylistEntriesView> {
  /// Dies with the page, so leaving it clears the filter.
  final _filter = InPageFilterController();

  @override
  InPageFilterController get filterController => _filter;

  /// An empty playlist has nothing to filter and shows no box.
  @override
  bool get filterAvailable => widget.loadMatches != null && _cache.count > 0;

  late final PlaylistRowCache _cache;
  final _writes = PlaylistWriteGate();

  @override
  PlaylistRowCache get dragCache => _cache;

  @override
  PlaylistWriteGate get dragWrites => _writes;

  /// Heads below this were read before the last write ended.
  var _minSeq = 0;

  /// A play is waiting for writes or reading its queue.
  var _playing = false;

  @override
  void initState() {
    super.initState();
    _cache = PlaylistRowCache(
      load: widget.loadRows,
      onChanged: () {
        if (mounted) setState(() {});
      },
    )..reset(widget.head.playlist.entryCount);
  }

  @override
  void didUpdateWidget(PlaylistEntriesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Identity, not equality: a rebuild with the same head (a reload state
    // after a write) is not new data.
    if (identical(oldWidget.head, widget.head)) return;
    // A head read before the last write ended may still have the old count;
    // one that arrives mid-write is not the state the screen is heading to.
    // After the write ends a fresh head is read, which is the one to take.
    if (_writes.busy || widget.headSeq < _minSeq) return;
    final count = widget.head.playlist.entryCount;
    if (dragging) {
      deferredCount = count;
    } else {
      _cache.reset(count);
    }
  }

  @override
  void dispose() {
    dragTimeout?.cancel();
    _cache.dispose();
    _writes.dispose();
    _filter.dispose();
    super.dispose();
  }

  /// Applies [edit] to the cache at once and runs [save]; the cache is held
  /// from the first write until the last one ends.
  Future<void> _write(
    void Function() edit,
    Future<bool> Function() save,
  ) async {
    // The head the drag put off would be read before this write: the settle
    // reads a newer one.
    deferredCount = null;
    setState(() {
      if (_writes.begin()) _cache.hold();
      edit();
    });
    try {
      // A throw counts as not saved; the head read after the write shows
      // what the database holds.
      if (!await save()) _log.fine('A playlist write was not saved');
    } catch (error, stack) {
      _log.warning('A playlist write failed', error, stack);
    } finally {
      if (_writes.end()) _settle();
    }
  }

  void _settle() {
    _cache.release();
    if (!mounted) return;
    final minSeq = widget.onSettled?.call();
    if (minSeq != null) _minSeq = minSeq;
    setState(() {});
  }

  void _onReorder(int from, int to) {
    final onMove = widget.onMove;
    final picked = dragEntryId;
    dragging = false;
    dragEntryId = null;
    // One write at a time: a second drop would be counted against an order
    // the database may never get if the first write fails.
    // The row the user picked up, wherever the cache has it now. Not cached
    // any more: nothing to move.
    final entryId = picked ?? _cache.rowAt(from)?.entryId;
    final current = entryId == null ? null : _cache.indexOfEntry(entryId);
    if (onMove == null ||
        from == to ||
        _writes.busy ||
        entryId == null ||
        current == null ||
        current == to) {
      takeDeferredHead();
      return;
    }
    unawaited(
      _write(() => _cache.move(current, to), () => onMove(entryId, to)),
    );
  }

  void _onRemove(PlaylistEntryRow entry) {
    final onRemove = widget.onRemove;
    // Looked up now, not when the row was built: another removal in the same
    // frame has moved the rows.
    final index = _cache.indexOfEntry(entry.entryId);
    if (onRemove == null || index == null) return;
    unawaited(
      _write(() => _cache.removeAt(index), () => onRemove(entry.entryId)),
    );
  }

  /// Plays after the writes under way; a second tap while one is waiting or
  /// reading the queue is ignored.
  Future<void> _play(int? entryId, int indexHint) async {
    if (_playing) return;
    _playing = true;
    try {
      await _writes.afterWrites();
      if (!mounted) return;
      await widget.onPlayFrom(entryId, indexHint);
    } catch (error, stack) {
      _log.severe('Playing a playlist failed', error, stack);
    } finally {
      _playing = false;
    }
  }

  /// Shuffles after the writes under way; same guard as [_play].
  Future<void> _shuffle() async {
    if (_playing) return;
    _playing = true;
    final onShuffle = widget.onShuffle!;
    try {
      await _writes.afterWrites();
      if (!mounted) return;
      await onShuffle();
    } catch (error, stack) {
      _log.severe('Shuffling a playlist failed', error, stack);
    } finally {
      _playing = false;
    }
  }

  /// The filter reads after the writes under way, so it sees their result.
  Future<PlaylistMatches> _matches(List<String> terms) async {
    await _writes.afterWrites();
    if (!mounted) return PlaylistMatches.empty;
    return widget.loadMatches!(terms);
  }

  /// Plays the filtered rows; same guard as [_play].
  Future<void> _playRows(List<PlaylistEntryRow> rows, int index) async {
    if (_playing) return;
    _playing = true;
    try {
      await _writes.afterWrites();
      if (!mounted) return;
      await widget.onPlayRows!(rows, index);
    } catch (error, stack) {
      _log.severe('Playing filtered playlist rows failed', error, stack);
    } finally {
      _playing = false;
    }
  }

  Future<void> _queueAll(QueueAction action) async {
    final onQueueAction = widget.onQueueAction;
    if (onQueueAction == null) return;
    await _writes.afterWrites();
    if (mounted) onQueueAction(action);
  }

  Widget _row(BuildContext context, int index) {
    final entry = _cache.rowAt(index);
    // Different key types, so a slot and a row never share an element.
    if (entry == null) {
      return PlaylistEntryPlaceholder(key: ValueKey('slot-$index'));
    }
    final onEntryAction = widget.onEntryQueueAction;
    final favorites = widget.head.playlist.isFavorites;
    return PlaylistEntryTile(
      // The entry id, not the path: the same file may be in the playlist
      // twice.
      key: ValueKey(entry.entryId),
      entry: entry,
      index: index,
      reorderable: widget.onMove != null,
      onTap: entry.track == null
          ? null
          : () => unawaited(_play(entry.entryId, index)),
      onRemove: widget.onRemove == null ? null : () => _onRemove(entry),
      favorites: favorites,
      onQueueAction: entry.track == null || onEntryAction == null
          ? null
          : (action) => onEntryAction(entry, action),
    );
  }

  @override
  Widget build(BuildContext context) {
    final head = widget.head;
    final count = _cache.count;
    final onQueueAction = widget.onQueueAction;
    final canFilter = filterAvailable;
    if (!canFilter && _filter.isOpen) {
      // The last entry went away: the box is gone, and so is its filter.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !filterAvailable) _filter.close();
      });
    }

    return ListenableBuilder(
      listenable: _filter,
      builder: (context, _) => PlaylistPageLayout(
        head: head,
        count: count,
        filter: _filter,
        canFilter: canFilter,
        onPointerEnd: onPointerEnd,
        onReorderStart: onReorderStart,
        onReorderEnd: onReorderEnd,
        onReorder: _onReorder,
        rowBuilder: _row,
        loadMatches: _matches,
        onPlayRows: (rows, index) => unawaited(_playRows(rows, index)),
        onPlay: head.hasPlayable ? () => unawaited(_play(null, 0)) : null,
        onShuffle: head.hasPlayable && widget.onShuffle != null
            ? () => unawaited(_shuffle())
            : null,
        onQueueAction: !head.hasPlayable || onQueueAction == null
            ? null
            : (action) => unawaited(_queueAll(action)),
        onEntryQueueAction: widget.onEntryQueueAction,
        onRename: widget.onRename,
        onDelete: widget.onDelete,
        onExport: widget.onExport,
      ),
    );
  }
}
