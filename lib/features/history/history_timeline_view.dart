import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/song_tile.dart' show SongTilePlaceholder;
import 'history_day_header.dart';
import 'history_play_tile.dart';
import 'history_timeline_index.dart';

/// Key of the sticky header, for tests.
const historyStickyHeaderKey = ValueKey('history-sticky-header');

/// The timeline: one fixed-extent list of day headers and plays, with the
/// header of the day at the top drawn over it as the sticky header.
///
/// The sticky header is not part of the scrolling: it reads the scroll
/// offset, finds the line at the top (`offset ~/ extent`) and draws that
/// line's day. It swallows pointer events, so what it covers is not hit.
class HistoryTimelineView extends StatelessWidget {
  const HistoryTimelineView({
    super.key,
    required this.controller,
    required this.index,
    required this.rowsOf,
    required this.now,
    required this.onTap,
    required this.onMenu,
    this.olderYear,
    this.onOlderYear,
  });

  final ScrollController controller;
  final HistoryTimelineIndex index;

  /// The plays of the day starting at the given epoch ms, null while unread.
  final List<HistoryPlayRow>? Function(int dayStart) rowsOf;
  final DateTime now;

  /// A play was tapped: the play and the start of its day.
  final void Function(HistoryPlayRow row, int dayStart) onTap;

  /// A play's menu was asked for at the given global position.
  final void Function(HistoryPlayRow row, Offset position) onMenu;

  /// The next older year with plays, offered at the end of the list.
  final int? olderYear;
  final VoidCallback? onOlderYear;

  Widget _header(int day) {
    final d = index.days[day];
    return HistoryDayHeader(
      day: DateTime.fromMillisecondsSinceEpoch(d.dayStart),
      count: d.count,
      now: now,
    );
  }

  Widget _item(BuildContext context, int i) {
    if (index.isFooter(i)) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: TextButton(
            onPressed: onOlderYear,
            child: Text(context.l10n.historyOlderYear(olderYear ?? 0)),
          ),
        ),
      );
    }
    final (:day, :row) = index.itemAt(i);
    if (row < 0) return _header(day);
    final dayStart = index.days[day].dayStart;
    final rows = rowsOf(dayStart);
    if (rows == null || row >= rows.length) {
      return const SizedBox(
        height: historyRowExtent,
        child: ClipRect(child: SongTilePlaceholder(compact: true)),
      );
    }
    final play = rows[row];
    return HistoryPlayTile(
      key: ValueKey(play.id),
      row: play,
      onTap: play.track == null ? null : () => onTap(play, dayStart),
      onMenu: (position) => onMenu(play, position),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = index.itemCount;
    if (count == 0) return const SizedBox.shrink();
    return Stack(
      children: [
        ListView.builder(
          controller: controller,
          itemExtent: historyRowExtent,
          itemCount: count,
          itemBuilder: _item,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: historyRowExtent,
          child: AbsorbPointer(
            key: historyStickyHeaderKey,
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final offset = controller.hasClients ? controller.offset : 0.0;
                final top = (math.max(0.0, offset) ~/ historyRowExtent).clamp(
                  0,
                  count - 1,
                );
                final day = index.dayIndexAtItem(top);
                if (day >= index.days.length) return const SizedBox.shrink();
                return _header(day);
              },
            ),
          ),
        ),
      ],
    );
  }
}
