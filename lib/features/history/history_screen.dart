import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/in_page_filter.dart';
import '../../shared/in_page_filter_host.dart';
import '../../shared/widgets/detail_page/tracks_toolbar.dart';
import '../../shared/widgets/library_loading.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'history_calendar_dialog.dart';
import 'history_days.dart';
import 'history_filter_results.dart';
import 'history_page_actions.dart';
import 'history_page_layout.dart';
import 'history_providers.dart';
import 'history_screen_states.dart';
import 'history_side_pane.dart' show HistoryPageCallbacks;
import 'history_timeline_body.dart';
import 'history_year_chips.dart';

/// The History page: a side pane (a header in a narrow window) with the
/// totals and Play / Shuffle, beside every play of one year, newest first,
/// grouped by day. Chips pick the year, a calendar jumps to a day, a tap plays
/// the songs of its day and the row menu queues a song or removes the play.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with InPageFilterHost<HistoryScreen> {
  /// The year the user picked; null (or one with no plays left) shows the
  /// newest year.
  int? _picked;
  final _jump = HistoryJumpHandle();
  final _filter = InPageFilterController();

  /// The page lists plays; set on every build.
  var _hasPlays = false;

  @override
  InPageFilterController get filterController => _filter;

  @override
  bool get filterAvailable => _hasPlays;

  /// Totals of the last year read, shown while the picked year's are read, so
  /// the toolbar text does not pop out and in on a year change.
  HistoryRangeSummary? _totals;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _openCalendar(int year) async {
    final List<HistoryDayCount> counts;
    try {
      counts = await ref.read(historyDayCountsProvider(year).future);
    } on Object {
      // The provider logged it; the page shows the failure.
      return;
    }
    if (!mounted) return;
    final day = await showHistoryCalendar(context, year: year, counts: counts);
    if (day != null) _jump.jump(day);
  }

  void _openYear(int year) => setState(() => _picked = year);

  /// The right column: toolbar (totals of the year, filter, calendar), year
  /// chips (one per year with plays, none without plays), then the timeline of
  /// the year.
  Widget _column(List<int> years, int year) {
    final l10n = context.l10n;
    final older = years.where((y) => y < year).firstOrNull;
    final bounds = dayBoundsOfYear(year);
    final read = ref
        .watch(
          historyRangeSummaryProvider((start: bounds.first, end: bounds.last)),
        )
        .value;
    if (read != null) _totals = read;
    final totals = read ?? _totals;
    return ListenableBuilder(
      listenable: _filter,
      builder: (context, _) {
        final filtering = _filter.isFiltering;
        return Column(
          children: [
            TracksToolbar(
              summary: totals == null
                  ? ''
                  : [
                      l10n.historyListenCount(totals.plays),
                      l10n.albumsSongCount(totals.tracks),
                    ].join(' · '),
              filter: _filter,
              trailing: [
                IconButton(
                  icon: const Icon(AppIcons.calendar),
                  tooltip: l10n.historyCalendar,
                  // The calendar jumps in the timeline, which is hidden while
                  // the filter lists plays.
                  onPressed: filtering ? null : () => _openCalendar(year),
                ),
              ],
            ),
            if (years.isNotEmpty)
              HistoryYearChips(
                years: years,
                selected: year,
                onSelected: _openYear,
              ),
            Expanded(
              child: Stack(
                children: [
                  // Kept mounted while filtering: closing the filter comes
                  // back to the same scroll position.
                  Offstage(
                    offstage: filtering,
                    child: TickerMode(
                      enabled: !filtering,
                      child: HistoryTimelineBody(
                        key: ValueKey(year),
                        year: year,
                        jump: _jump,
                        olderYear: older,
                        onOlderYear: older == null
                            ? null
                            : () => _openYear(older),
                      ),
                    ),
                  ),
                  if (filtering)
                    HistoryFilterResults(
                      year: year,
                      terms: _filter.terms,
                      query: _filter.query,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  HistoryPageCallbacks _callbacks() => (
    onPlay: () => unawaited(playAllHistory(ref)),
    onShuffle: () => unawaited(shuffleAllHistory(ref, context)),
    onQueueAction: (action) => queueAllHistory(ref, context, action),
  );

  Widget _states(Widget body) =>
      PageScaffold(title: context.l10n.navHistory, body: body);

  @override
  Widget build(BuildContext context) {
    if (ref.watch(libraryDatabaseProvider) == null) {
      return _states(const HistoryUnavailable());
    }
    final years = ref.watch(historyYearsProvider);
    if (!years.hasValue) {
      return _states(
        years.hasError ? const HistoryLoadFailed() : const LibraryLoading(),
      );
    }
    final list = years.value!;
    _hasPlays = list.isNotEmpty;
    if (list.isEmpty) return _states(const HistoryEmpty());
    final year = list.contains(_picked) ? _picked! : list.first;
    final overview = ref.watch(historyOverviewProvider).value;
    return Material(
      type: MaterialType.transparency,
      child: HistoryPageLayout(
        overview: overview,
        callbacks: _callbacks(),
        column: _column(list, year),
      ),
    );
  }
}
