import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/library_loading.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'history_calendar_dialog.dart';
import 'history_providers.dart';
import 'history_screen_states.dart';
import 'history_timeline_body.dart';
import 'history_top_view.dart';
import 'history_year_chips.dart';

/// The History page, two tabs that keep their state side by side. Journal:
/// every play, newest first, grouped by day; one year is shown at a time
/// (chips pick it), a calendar jumps to a day, a tap plays the songs of its
/// day and the row menu queues a song or removes the play. Most played: the
/// songs played most in a range of days. The hidden tab sits under a
/// disabled `TickerMode`, which pauses its providers.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  /// The year the user picked; null (or one with no plays left) shows the
  /// newest year.
  int? _picked;
  final _jump = HistoryJumpHandle();

  @override
  void dispose() {
    _tabs.dispose();
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

  /// The journal tab and, when it has plays, the button that opens its
  /// calendar.
  (Widget, List<Widget>?) _journal(AsyncValue<List<int>> years) {
    if (!years.hasValue) {
      return (
        years.hasError ? const HistoryLoadFailed() : const LibraryLoading(),
        null,
      );
    }
    final list = years.value!;
    if (list.isEmpty) return (const HistoryEmpty(), null);
    final year = list.contains(_picked) ? _picked! : list.first;
    final older = list.where((y) => y < year).firstOrNull;
    final body = Column(
      children: [
        if (list.length > 1)
          HistoryYearChips(
            years: list,
            selected: year,
            onSelected: (y) => setState(() => _picked = y),
          ),
        Expanded(
          child: HistoryTimelineBody(
            key: ValueKey(year),
            year: year,
            jump: _jump,
            olderYear: older,
            onOlderYear: older == null
                ? null
                : () => setState(() => _picked = older),
          ),
        ),
      ],
    );
    return (
      body,
      [
        IconButton(
          icon: const Icon(AppIcons.calendar),
          tooltip: context.l10n.historyCalendar,
          onPressed: () => _openCalendar(year),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (ref.watch(libraryDatabaseProvider) == null) {
      return PageScaffold(
        title: l10n.navHistory,
        body: const HistoryUnavailable(),
      );
    }
    final (journal, actions) = _journal(ref.watch(historyYearsProvider));
    final active = _tabs.index;
    return PageScaffold(
      title: l10n.navHistory,
      actions: active == 0 ? actions : null,
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l10n.historyTabTimeline),
              Tab(text: l10n.historyTabTop),
            ],
          ),
          Expanded(
            child: IndexedStack(
              index: active,
              children: [
                TickerMode(enabled: active == 0, child: journal),
                TickerMode(enabled: active == 1, child: const HistoryTopView()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
