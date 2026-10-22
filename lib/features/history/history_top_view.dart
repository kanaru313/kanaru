import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/library_loading.dart';
import '../../shared/enqueue_tracks.dart';
import 'history_clock.dart';
import 'history_play_menu.dart';
import 'history_play_tile.dart' show historyRowExtent;
import 'history_providers.dart';
import 'history_range.dart';
import 'history_range_bar.dart';
import 'history_routes.dart';
import 'history_screen_states.dart';
import 'history_top_actions.dart';
import 'history_top_queue.dart';
import 'history_top_tile.dart';

/// The Most played tab: the songs played most in a range of days, ranked.
/// Its range lives in this widget's state, so it survives a switch of tab.
///
/// While a new range or a change to the plays is read, the list on show
/// stays and a thin bar runs over it, so the list never flashes empty.
class HistoryTopView extends ConsumerStatefulWidget {
  const HistoryTopView({super.key});

  @override
  ConsumerState<HistoryTopView> createState() => _HistoryTopViewState();
}

class _HistoryTopViewState extends ConsumerState<HistoryTopView> {
  var _range = const HistoryRangeState();

  /// The list last read; stays on show while the next one is read.
  List<HistoryTopRow>? _shown;

  Future<void> _pickCustom(DateTime now) async {
    final played = ref.read(historyPlayedRangeProvider).value;
    if (played == null) return;
    final bounds = pickerBounds(played, now);
    final initial = clampedCustom(_range, bounds);
    final picked = await showDateRangePicker(
      context: context,
      currentDate: now,
      firstDate: bounds.first,
      lastDate: bounds.last,
      initialDateRange: initial == null
          ? null
          : DateTimeRange(start: initial.start, end: initial.end),
    );
    if (picked == null || !mounted) return;
    setState(() => _range = _range.withCustom(picked.start, picked.end));
  }

  void _play(List<HistoryTopRow> rows, int index) {
    final queue = historyTopQueue(
      rows,
      index,
      ref.read(coverCacheDirectoryProvider),
    );
    if (queue != null) playTracks(ref, queue.tracks, queue.start);
  }

  Future<void> _openMenu(HistoryTopRow row, Offset position) async {
    final choice = await showHistoryPlayMenu(
      context,
      position,
      canQueue: row.track != null,
      canDelete: false,
    );
    if (choice == null || !mounted) return;
    if (choice == HistoryPlayChoice.trackHistory) {
      context.go(historyTrackLocation(row.path));
      return;
    }
    final action = historyQueueActionOf(choice);
    final track = historyTopTrackOf(row, ref.read(coverCacheDirectoryProvider));
    if (action == null || track == null) return;
    enqueueLoaded(ref, context, action, [track], row.track!.title);
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(historyNowProvider)();
    final played = ref.watch(historyPlayedRangeProvider);
    final playedRange = played.value;
    var loading = played.isLoading;
    var failed = played.hasError;
    if (played.hasValue && playedRange == null) {
      _shown = const [];
    } else if (playedRange != null) {
      final window = _range.window(now);
      final all = window == null || windowCoversPlays(window, playedRange);
      final top = ref.watch(
        historyTopProvider(
          all
              ? (start: null, end: null)
              : (start: window.start, end: window.end),
        ),
      );
      if (top.hasValue) _shown = top.value;
      loading = top.isLoading;
      failed = top.hasError;
    }
    final rows = _shown;

    Widget body;
    if (failed) {
      body = const HistoryLoadFailed();
    } else if (rows == null) {
      body = const LibraryLoading();
    } else if (rows.isEmpty) {
      body = loading
          ? const LibraryLoading()
          : EmptyState(
              icon: AppIcons.history,
              title: context.l10n.historyTopEmpty,
            );
    } else {
      body = ListView.builder(
        itemExtent: historyRowExtent,
        itemCount: rows.length,
        itemBuilder: (context, i) => HistoryTopTile(
          rank: i + 1,
          row: rows[i],
          onTap: rows[i].track == null ? null : () => _play(rows, i),
          onMenu: (position) => unawaited(_openMenu(rows[i], position)),
        ),
      );
    }
    return Column(
      children: [
        HistoryRangeBar(
          state: _range,
          now: now,
          canPickCustom: playedRange != null,
          onPreset: (p) => setState(() => _range = _range.withPreset(p)),
          onCustom: () => unawaited(_pickCustom(now)),
          onShift: (d) => setState(
            () => _range = d < 0 ? _range.previous() : _range.next(),
          ),
        ),
        HistoryTopActions(
          rows: rows ?? const [],
          rangeText: historyRangeText(context, _range, now),
        ),
        SizedBox(
          height: 2,
          child: loading ? const LinearProgressIndicator() : null,
        ),
        Expanded(child: body),
      ],
    );
  }
}
