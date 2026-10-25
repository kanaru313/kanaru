import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../core/database/search_playlist_queries.dart';
import '../../core/m3u/m3u_write.dart' show M3uPathStyle;
import '../../shared/in_page_filter.dart';
import '../../shared/widgets/detail_page/cover_tint_page_background.dart';
import '../../shared/widgets/detail_page/detail_side_pane.dart';
import '../../shared/widgets/detail_page/tracks_toolbar.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'playlist_entry_lift.dart';
import 'playlist_entry_tile.dart';
import 'playlist_filter_results.dart';
import 'playlist_header.dart';
import 'playlist_screen_states.dart' show PlaylistEmptyState;
import 'playlist_side_pane.dart';

/// The look of a playlist page, tinted by its cover: a side pane beside the
/// list in a wide window, a header above it in a narrow one; then the songs
/// toolbar (with the filter), then the empty state, the
/// filter results or the reorderable rows. Holds no state; everything comes
/// from `PlaylistEntriesView`.
class PlaylistPageLayout extends StatelessWidget {
  const PlaylistPageLayout({
    super.key,
    required this.head,
    required this.count,
    required this.filter,
    required this.canFilter,
    required this.onPointerEnd,
    required this.onReorderStart,
    required this.onReorderEnd,
    required this.onReorder,
    required this.rowBuilder,
    required this.loadMatches,
    required this.onPlayRows,
    this.onPlay,
    this.onShuffle,
    this.onQueueAction,
    this.onEntryQueueAction,
    this.onRename,
    this.onDelete,
    this.onExport,
  });

  final PlaylistPageHead head;

  /// Slots in the list.
  final int count;
  final InPageFilterController filter;

  /// The page has a filter box.
  final bool canFilter;

  /// Pointer up / cancel anywhere in the scroll view (see drag tracking).
  final void Function(PointerEvent event) onPointerEnd;
  final ValueChanged<int> onReorderStart;
  final ValueChanged<int> onReorderEnd;
  final ReorderCallback onReorder;
  final IndexedWidgetBuilder rowBuilder;

  /// Reads the entries that match the filter terms.
  final Future<PlaylistMatches> Function(List<String> terms) loadMatches;

  /// Plays the filtered rows from `index`.
  final void Function(List<PlaylistEntryRow> rows, int index) onPlayRows;

  /// Null while nothing in the playlist can play.
  final VoidCallback? onPlay;

  /// Null while nothing in the playlist can play: Shuffle is disabled.
  final VoidCallback? onShuffle;
  final void Function(QueueAction action)? onQueueAction;
  final void Function(PlaylistEntryRow entry, QueueAction action)?
  onEntryQueueAction;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final ValueChanged<M3uPathStyle>? onExport;

  @override
  Widget build(BuildContext context) {
    return CoverTintPageBackground.blend(
      coverKeys: head.coverKeys,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= detailSidePaneMinPageWidth;
          final content = _scrollView(context, wide: wide);
          if (!wide) return content;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlaylistSidePane(
                head: head,
                count: count,
                onPlay: onPlay,
                onShuffle: onShuffle,
                onQueueAction: onQueueAction,
                onRename: onRename,
                onDelete: onDelete,
                onExport: onExport,
              ),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  /// The scrolling column. The pointer listener wraps it only, not the side
  /// pane: drags start from rows.
  Widget _scrollView(BuildContext context, {required bool wide}) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: onPointerEnd,
      onPointerCancel: onPointerEnd,
      child: CustomScrollView(
        slivers: [
          if (!wide)
            SliverToBoxAdapter(
              child: PlaylistHeader(
                head: head,
                count: count,
                onPlay: onPlay,
                onShuffle: onShuffle,
                onQueueAction: onQueueAction,
                onRename: onRename,
                onDelete: onDelete,
                onExport: onExport,
              ),
            ),
          if (canFilter)
            SliverTracksToolbar(
              songCount: count,
              durationMs: null,
              filter: filter,
            ),
          if (count == 0)
            // EmptyState scrolls on its own and measures with a LayoutBuilder,
            // which a non-scrolling fill cannot size.
            SliverFillRemaining(
              child: PlaylistEmptyState(favorites: head.playlist.isFavorites),
            )
          else if (canFilter && filter.isFiltering)
            PlaylistFilterResults(
              terms: filter.terms,
              query: filter.query,
              refresh: head,
              load: loadMatches,
              onPlay: onPlayRows,
              onEntryQueueAction: onEntryQueueAction,
              favorites: head.playlist.isFavorites,
            )
          else
            SliverReorderableList(
              prototypeItem: PlaylistEntryTile(
                entry: prototypePlaylistEntry,
                index: 0,
                onRemove: () {},
              ),
              itemCount: count,
              onReorderStart: onReorderStart,
              onReorderEnd: onReorderEnd,
              onReorderItem: onReorder,
              proxyDecorator: playlistEntryLift(context),
              itemBuilder: rowBuilder,
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
