import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_queries.dart';
import '../../core/database/library_startup.dart';
import '../../shared/widgets/library_loading.dart';
import 'history_day_row_cache.dart';
import 'history_days.dart';
import 'history_line_metrics.dart';
import 'history_play_menu_actions.dart';
import 'history_plays_version.dart';
import 'history_providers.dart';
import 'history_screen_states.dart';
import 'history_timeline_actions.dart';
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

class _HistoryTimelineBodyState extends ConsumerState<HistoryTimelineBody>
    with
        HistoryPlayMenuActions<HistoryTimelineBody>,
        HistoryTimelineActions<HistoryTimelineBody> {
  final _controller = ScrollController();
  late final HistoryDayRowCache _cache;

  /// What the list shows; null until the first read.
  HistoryTimelineIndex? _index;

  /// The newest read, held back while the list is scrolled down.
  List<HistoryDayCount>? _held;
  Object? _lastCounts;

  /// Height of a line and of a day bar, read from the theme and text scale on
  /// every build; the jump and the scrolled-away test use them between builds.
  double _extent = 80;
  double _bar = 48;

  @override
  void initState() {
    super.initState();
    _cache = HistoryDayRowCache(
      load: loadDay,
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

  @override
  List<HistoryPlayRow>? rowsOfDay(int dayStart) => _cache.rowsOf(dayStart);

  @override
  Future<List<HistoryPlayRow>> loadDay(int dayStart) async {
    final end = addDays(
      localDay(DateTime.fromMillisecondsSinceEpoch(dayStart)),
      1,
    );
    final rows = await ref
        .read(libraryDatabaseProvider)!
        .historyDayPlays(dayStart, end.millisecondsSinceEpoch);
    return _heldRows(dayStart, rows);
  }

  /// The header of a day says how many plays the page shows for it, so its
  /// rows (and what a menu acts on) must be that many too. A read that finds
  /// more has plays the page holds back or has not applied yet. Those are the
  /// newest (a play is stamped with the time playback started and its row is
  /// written a little later, but still after every play shown, and rows run
  /// newest first), so they are the leading rows and are cut. Taking the last
  /// rows is the same cut without needing the time or id of the newest play
  /// shown. Removals and changes are never held, so a day cannot have fewer
  /// rows than its count.
  List<HistoryPlayRow> _heldRows(int dayStart, List<HistoryPlayRow> rows) {
    final shown = _index?.countOfDay(dayStart) ?? -1;
    if (shown < 0 || rows.length <= shown) return rows;
    return rows.sublist(rows.length - shown);
  }

  bool get _scrolledAway =>
      _controller.hasClients && _controller.offset > _extent;

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
    final d = index.dayIndexOfStart(localDay(day).millisecondsSinceEpoch);
    if (d < 0) return;
    // A day near the end cannot reach the top: the list stops at its end.
    _controller.jumpTo(
      math.min(
        index.barOffsetOfDay(d, _extent, _bar),
        _controller.position.maxScrollExtent,
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
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    _extent = historyLineExtent(theme, scaler);
    _bar = historyDayBarHeight(theme, scaler);
    return HistoryTimelineView(
      controller: _controller,
      index: index,
      rowsOf: _cache.rowsOf,
      onTap: playFromRow,
      onMenu: openPlayMenu,
      onDayMenu: openDayMenu,
      olderYear: widget.olderYear,
      onOlderYear: widget.onOlderYear,
    );
  }
}
