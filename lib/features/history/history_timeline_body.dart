import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_queries.dart';
import '../../core/database/library_startup.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/library_loading.dart';
import '../../l10n/l10n.dart';
import 'history_clock.dart';
import 'history_day_queue.dart';
import 'history_day_row_cache.dart';
import 'history_days.dart';
import 'history_delete_undo.dart';
import 'history_play_menu.dart';
import 'history_play_tile.dart';
import 'history_plays_version.dart';
import 'history_providers.dart';
import 'history_routes.dart';
import 'history_screen_states.dart';
import 'history_timeline_index.dart';
import 'history_timeline_view.dart';
import 'history_tracks_version.dart';

/// Lets the page header's calendar button scroll the timeline.
class HistoryJumpHandle {
  void Function(DateTime day)? _jump;

  /// Scrolls the timeline to the header of [day], when it has one.
  void jump(DateTime day) => _jump?.call(day);
}

/// The timeline of one year: reads the plays per day, keeps the rows of the
/// days on screen in a cache and handles taps, menus and removals.
///
/// A play that arrives while the list is scrolled away from the top is held
/// back and shown when the list comes back near the top: adding a line above
/// the reader would move everything under them. Removals show at once.
/// Build one body per year (give it a key of the year).
class HistoryTimelineBody extends ConsumerStatefulWidget {
  const HistoryTimelineBody({
    super.key,
    required this.year,
    required this.jump,
    this.olderYear,
    this.onOlderYear,
  });

  final int year;
  final HistoryJumpHandle jump;

  /// The next older year with plays, offered at the end of the list.
  final int? olderYear;
  final VoidCallback? onOlderYear;

  @override
  ConsumerState<HistoryTimelineBody> createState() =>
      _HistoryTimelineBodyState();
}

class _HistoryTimelineBodyState extends ConsumerState<HistoryTimelineBody> {
  final _controller = ScrollController();
  late final HistoryDayRowCache _cache;

  /// What the list shows; null until the first read.
  HistoryTimelineIndex? _index;

  /// The newest read, held back while the list is scrolled down.
  List<HistoryDayCount>? _held;
  Object? _lastCounts;

  @override
  void initState() {
    super.initState();
    _cache = HistoryDayRowCache(
      load: _loadDay,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    _controller.addListener(_onScroll);
    widget.jump._jump = _jumpTo;
  }

  @override
  void dispose() {
    // A body of the next year may have taken the handle already.
    if (widget.jump._jump == _jumpTo) widget.jump._jump = null;
    _controller.dispose();
    _cache.dispose();
    super.dispose();
  }

  Future<List<HistoryPlayRow>> _loadDay(int dayStart) async {
    final end = addDays(
      localDay(DateTime.fromMillisecondsSinceEpoch(dayStart)),
      1,
    );
    final rows = await ref
        .read(libraryDatabaseProvider)!
        .historyDayPlays(dayStart, end.millisecondsSinceEpoch);
    return _heldRows(dayStart, rows);
  }

  /// While a read is held back the header of a day says how many plays it had
  /// then, so its rows must be that many too: a read that finds more has the
  /// held plays, which are the newest (a play is stamped with the time
  /// playback started and its row is written a little later, but still
  /// after every play shown, and rows run newest first), so they are the
  /// leading rows and are cut. Taking the last rows is the same cut
  /// without needing the time or id of the newest play shown. Removals and
  /// changes are never held, so a day cannot have fewer rows than its count.
  List<HistoryPlayRow> _heldRows(int dayStart, List<HistoryPlayRow> rows) {
    final shown = _index?.countOfDay(dayStart) ?? -1;
    if (_held == null || shown < 0 || rows.length <= shown) return rows;
    return rows.sublist(rows.length - shown);
  }

  bool get _scrolledAway =>
      _controller.hasClients && _controller.offset > historyRowExtent;

  /// Takes a read of the days: now, or held back when it only adds plays and
  /// the reader is scrolled away from the top.
  void _receive(List<HistoryDayCount> counts) {
    if (identical(counts, _lastCounts)) return;
    _lastCounts = counts;
    final version = ref.read(historyPlaysVersionProvider.notifier);
    if (_index != null && !version.mustApplyNow && _scrolledAway) {
      // A day read just before this may already hold the new plays: read the
      // days on screen again so they are cut to the shown counts.
      if (_held == null) _cache.invalidate();
      _held = counts;
      return;
    }
    _show(counts);
  }

  void _show(List<HistoryDayCount> counts) {
    _held = null;
    _index = HistoryTimelineIndex(
      counts,
      hasOlderYear: widget.olderYear != null,
    );
    _cache.invalidate();
    ref.read(historyPlaysVersionProvider.notifier).applied();
  }

  void _onScroll() {
    final held = _held;
    if (held == null || _scrolledAway) return;
    setState(() => _show(held));
  }

  void _jumpTo(DateTime day) {
    final index = _index;
    if (index == null || !_controller.hasClients) return;
    final line = index.firstIndexOfDay(localDay(day).millisecondsSinceEpoch);
    if (line < 0) return;
    _controller.jumpTo(
      math.min(line * historyRowExtent, _controller.position.maxScrollExtent),
    );
  }

  void _play(HistoryPlayRow row, int dayStart) {
    final queue = historyDayQueue(
      _cache.rowsOf(dayStart) ?? [row],
      row,
      ref.read(coverCacheDirectoryProvider),
    );
    if (queue != null) playTracks(ref, queue.tracks, queue.start);
  }

  /// Opens the menu of [row]. The play is the one the menu was opened on:
  /// the list may move before a choice is made.
  Future<void> _openMenu(HistoryPlayRow row, Offset position) async {
    final choice = await showHistoryPlayMenu(
      context,
      position,
      canQueue: row.track != null,
    );
    if (choice == null || !mounted) return;
    final action = historyQueueActionOf(choice);
    if (action != null) {
      enqueueLoaded(ref, context, action, [
        historyTrackOf(row, ref.read(coverCacheDirectoryProvider)),
      ], row.track!.title);
      return;
    }
    if (choice == HistoryPlayChoice.trackHistory) {
      context.go(historyTrackLocation(row.path));
      return;
    }
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    unawaited(
      ref
          .read(historyDeleteUndoProvider)
          .delete(
            db: db,
            messenger: ScaffoldMessenger.of(context),
            l10n: context.l10n,
            version: ref.read(historyPlaysVersionProvider.notifier),
            playId: row.id,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(historyTracksVersionProvider, (_, _) {
      _cache.invalidate();
      setState(() {});
    });
    final counts = ref.watch(historyDayCountsProvider(widget.year));
    if (counts.hasValue) _receive(counts.value!);
    var index = _index;
    if (index == null) {
      return counts.hasError
          ? const HistoryLoadFailed()
          : const LibraryLoading();
    }
    if (index.hasOlderYear != (widget.olderYear != null)) {
      index = _index = HistoryTimelineIndex(
        index.days,
        hasOlderYear: widget.olderYear != null,
      );
    }
    return HistoryTimelineView(
      controller: _controller,
      index: index,
      rowsOf: _cache.rowsOf,
      now: ref.watch(historyNowProvider)(),
      onTap: _play,
      onMenu: _openMenu,
      olderYear: widget.olderYear,
      onOlderYear: widget.onOlderYear,
    );
  }
}
