import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import '../../shared/song_modal/song_modal_extras.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import '../../shared/widgets/song_card.dart';
import 'history_missing_play_modal.dart';
import 'history_routes.dart';
import 'history_song_modal_extras.dart';
import 'history_top_queue.dart';
import 'most_played_row_tile.dart';

/// The ranked songs of the Most played page, one fixed-height song row each.
///
/// [rows] are the songs on show in rank order and [ranks] their places in the
/// ranking (from 1), which differ from `1..n` while a filter hides rows. A tap
/// queues the songs of [rows] that can play, from the tapped one.
class MostPlayedList extends ConsumerStatefulWidget {
  const MostPlayedList({
    super.key,
    required this.rows,
    required this.ranks,
  }) : assert(rows.length == ranks.length);

  final List<HistoryTopRow> rows;
  final List<int> ranks;

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

  /// Song history and the rank chip for the modal of [row] at place [rank];
  /// built when the modal opens. Plays are not removed from here.
  SongModalExtras _extras(HistoryTopRow row, int rank) => historyPlayExtras(
    context: context,
    ref: ref,
    path: row.path,
    location: mostPlayedTrackLocation,
    headerNote: context.l10n.historyTopRankChip(
      rank,
      context.l10n.historyTopPlayCount(row.count),
    ),
  );

  /// The Missing-play modal of a row with no song in the library.
  void _openMissing(HistoryTopRow row, int rank, {required bool viaKeyboard}) {
    final extras = _extras(row, rank);
    openHistoryMissingPlayModal(
      context,
      path: row.path,
      chip: extras.headerNote!,
      extras: extras,
      viaKeyboard: viaKeyboard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extent = songCardExtent(theme, MediaQuery.textScalerOf(context));
    final rows = widget.rows;
    return ListView.builder(
      itemExtent: extent,
      itemCount: rows.length,
      itemBuilder: (context, i) {
        return MostPlayedRowTile(
          key: ValueKey(rows[i].path),
          rank: widget.ranks[i],
          row: rows[i],
          onTap: () => _play(i),
          onMenu: ({required viaKeyboard, required at}) =>
              _openMissing(rows[i], widget.ranks[i], viaKeyboard: viaKeyboard),
          onQueueAction: (action) => _queue(rows[i], action),
          modalExtras: () => _extras(rows[i], widget.ranks[i]),
        );
      },
    );
  }
}
