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
import 'history_year_chips.dart';

/// The History page: every play, newest first, grouped by day. One year is
/// shown at a time (chips pick it), a calendar jumps to a day, a tap plays
/// the songs of its day and the row menu queues a song or removes the play.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  /// The year the user picked; null (or one with no plays left) shows the
  /// newest year.
  int? _picked;
  final _jump = HistoryJumpHandle();

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final years = ref.watch(historyYearsProvider);
    Widget body;
    List<Widget>? actions;
    if (ref.watch(libraryDatabaseProvider) == null) {
      body = const HistoryUnavailable();
    } else if (years.hasValue) {
      final list = years.value!;
      if (list.isEmpty) {
        body = const HistoryEmpty();
      } else {
        final year = list.contains(_picked) ? _picked! : list.first;
        final older = list.where((y) => y < year).firstOrNull;
        actions = [
          IconButton(
            icon: const Icon(AppIcons.calendar),
            tooltip: l10n.historyCalendar,
            onPressed: () => _openCalendar(year),
          ),
        ];
        body = Column(
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
      }
    } else {
      body = years.hasError
          ? const HistoryLoadFailed()
          : const LibraryLoading();
    }
    return PageScaffold(title: l10n.navHistory, actions: actions, body: body);
  }
}
