import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'optimistic_order.dart';
import 'playlist_entry_tile.dart';
import 'playlist_header.dart';

/// A playlist page: header, then its entries as a list the user can
/// reorder by dragging a handle. A dropped row stays where it landed while
/// [onMove] runs, and goes back if it reports failure.
class PlaylistEntriesView extends StatefulWidget {
  const PlaylistEntriesView({
    super.key,
    required this.page,
    required this.onMove,
    required this.onRemove,
    required this.onPlayFrom,
    this.onQueueAction,
    this.onEntryQueueAction,
    required this.onRename,
    required this.onDelete,
  });

  final PlaylistPage page;

  /// Moves [entryId] so it ends up at index [to] of the list; completes with
  /// whether the move was saved. A throw counts as not saved. Drops are
  /// ignored while a move is running.
  final Future<bool> Function(int entryId, int to) onMove;

  /// Removes the entry with this id.
  final ValueChanged<int> onRemove;

  /// Plays from `shown[index]`. `shown` is the list as displayed: while a
  /// move is under way it differs from `page.entries`, and a queue built
  /// from the page would start at the wrong song. It may hold entries that
  /// cannot play; the receiver skips them.
  final void Function(List<PlaylistEntryRow> shown, int index) onPlayFrom;

  /// Queue menu of the header, for the whole playlist. `shown` is the list
  /// as displayed, as for [onPlayFrom]; it may hold entries that cannot play.
  final void Function(List<PlaylistEntryRow> shown, QueueAction action)?
  onQueueAction;

  /// Queue menu of one row.
  final void Function(PlaylistEntryRow entry, QueueAction action)?
  onEntryQueueAction;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  State<PlaylistEntriesView> createState() => _PlaylistEntriesViewState();
}

final _log = Logger('playlists');

class _PlaylistEntriesViewState extends State<PlaylistEntriesView> {
  final _order = OptimisticOrder();

  List<PlaylistEntryRow> get _shown =>
      _order.apply(widget.page.entries, (e) => e.entryId);

  @override
  void didUpdateWidget(PlaylistEntriesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Identity, not equality: a rebuild with the same page (a reload state
    // after a write) is not new data.
    if (!identical(oldWidget.page, widget.page)) {
      _order.onData([for (final e in widget.page.entries) e.entryId]);
    }
  }

  Future<void> _onReorder(int from, int to) async {
    // One write at a time: a second drop would be counted against an order
    // the database may never get if the first write fails.
    if (from == to || _order.busy) return;
    final moved = [..._shown];
    final entry = moved.removeAt(from);
    moved.insert(to, entry);
    setState(() => _order.begin([for (final e in moved) e.entryId]));
    var ok = false;
    try {
      ok = await widget.onMove(entry.entryId, to);
    } catch (error, stack) {
      // Same as a reported failure: the rows go back.
      _log.warning('Moving a playlist entry failed', error, stack);
    } finally {
      if (mounted) setState(() => _order.end(ok: ok));
    }
  }

  /// The row being dragged: its card gets a shadow and an opaque plate of
  /// the card's own size. The slot around the card (the row's inset) stays
  /// clear, so no slab bigger than the card is lifted.
  Widget _lift(Widget child, int index, Animation<double> animation) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: playlistEntryInset,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shown = _shown;
    final firstPlayable = shown.indexWhere((e) => e.track != null);
    final onQueueAction = widget.onQueueAction;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: PlaylistHeader(
            page: widget.page,
            onPlay: firstPlayable < 0
                ? null
                : () => widget.onPlayFrom(shown, firstPlayable),
            onQueueAction: firstPlayable < 0 || onQueueAction == null
                ? null
                : (action) => onQueueAction(shown, action),
            onRename: widget.onRename,
            onDelete: widget.onDelete,
          ),
        ),
        if (shown.isEmpty)
          // EmptyState scrolls on its own and measures with a LayoutBuilder,
          // which a non-scrolling fill cannot size.
          SliverFillRemaining(
            child: EmptyState(
              icon: Icons.queue_music,
              title: l10n.playlistEmptyTitle,
              message: l10n.playlistEmptyMessage,
            ),
          )
        else
          SliverReorderableList(
            itemExtent: playlistEntryExtent,
            itemCount: shown.length,
            onReorderItem: _onReorder,
            proxyDecorator: _lift,
            itemBuilder: (context, index) {
              final entry = shown[index];
              final onEntryAction = widget.onEntryQueueAction;
              return PlaylistEntryTile(
                // The entry id, not the path: the same file may be in the
                // playlist twice.
                key: ValueKey(entry.entryId),
                entry: entry,
                index: index,
                onTap: entry.track == null
                    ? null
                    : () => widget.onPlayFrom(shown, index),
                onRemove: () => widget.onRemove(entry.entryId),
                onQueueAction: entry.track == null || onEntryAction == null
                    ? null
                    : (action) => onEntryAction(entry, action),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}
