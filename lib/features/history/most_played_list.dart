import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import '../../shared/song_modal/song_modal_extras.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import '../../shared/widgets/song_card.dart';
import 'history_play_menu.dart';
import 'history_range.dart';
import 'history_routes.dart';
import 'history_song_modal_extras.dart';
import 'history_top_queue.dart';
import 'most_played_row_tile.dart';

/// The ranked songs of the Most played page, one fixed-height song row each,
/// and at the end a line saying the list was cut at [historyTopLimit].
///
/// [rows] are the songs on show in rank order and [ranks] their places in the
/// ranking (from 1), which differ from `1..n` while a filter hides rows. A tap
/// queues the songs of [rows] that can play, from the tapped one.
class MostPlayedList extends ConsumerStatefulWidget {
  const MostPlayedList({
    super.key,
    required this.rows,
    required this.ranks,
    required this.capped,
  }) : assert(rows.length == ranks.length);

  final List<HistoryTopRow> rows;
  final List<int> ranks;

  /// More songs were played than the ranking holds.
  final bool capped;

  @override
  ConsumerState<MostPlayedList> createState() => _MostPlayedListState();
}

class _MostPlayedListState extends ConsumerState<MostPlayedList> {
  void _play(int index) {
    final queue = historyTopQueue(
      widget.rows,
      index,
      ref.read(coverCacheDirectoryProvider),
    );
    if (queue != null) playTracks(ref, queue.tracks, queue.start);
  }

  /// Queue action picked in the song modal of [row]; dropped once the page is
  /// gone.
  void _queue(HistoryTopRow row, QueueAction action) {
    if (!mounted) return;
    final track = historyTopTrackOf(row, ref.read(coverCacheDirectoryProvider));
    if (track == null) return;
    enqueueLoaded(ref, context, action, [track], row.track!.title);
  }

  /// Song history for the modal of [row], with the listen count under the
  /// album; built when the modal opens. Plays are not removed from here.
  SongModalExtras _extras(HistoryTopRow row) => historyPlayExtras(
    context: context,
    ref: ref,
    path: row.path,
    location: mostPlayedTrackLocation,
    headerNote: context.l10n.historyTopPlayCount(row.count),
  );

  /// The small menu of a row with no song in the library.
  Future<void> _openMenu(HistoryTopRow row, Offset position) async {
    final choice = await showHistoryPlayMenu(
      context,
      position,
      canQueue: row.track != null,
      canDelete: false,
    );
    if (choice == null || !mounted) return;
    if (choice == HistoryPlayChoice.trackHistory) {
      context.go(mostPlayedTrackLocation(row.path));
      return;
    }
    final action = historyQueueActionOf(choice);
    final track = historyTopTrackOf(row, ref.read(coverCacheDirectoryProvider));
    if (action == null || track == null) return;
    enqueueLoaded(ref, context, action, [track], row.track!.title);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extent = songCardExtent(theme, MediaQuery.textScalerOf(context));
    final rows = widget.rows;
    return ListView.builder(
      itemExtent: extent,
      itemCount: rows.length + (widget.capped ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == rows.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(32, 12, 32, 4),
            child: Text(
              context.l10n.historyTopCapped(historyTopLimit),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return MostPlayedRowTile(
          key: ValueKey(rows[i].path),
          rank: widget.ranks[i],
          row: rows[i],
          onTap: () => _play(i),
          onMenu: (position) => unawaited(_openMenu(rows[i], position)),
          onQueueAction: (action) => _queue(rows[i], action),
          modalExtras: () => _extras(rows[i]),
        );
      },
    );
  }
}
