import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/song_modal/song_modal_extras.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import '../../shared/widgets/song_tile_placeholder.dart';
import 'history_day_header.dart';
import 'history_line_metrics.dart';
import 'history_play_row_tile.dart';
import 'history_timeline_index.dart';

/// Key of the pinned day bar, for tests.
const historyStickyHeaderKey = ValueKey('history-sticky-header');

/// The timeline: one list of day header lines and plays, with
/// the bar of the day at the top drawn over it as the pinned bar.
///
/// Every line is one song row tall ([HistoryLineMetrics.line]) except the
/// header lines, which are the bar plus a gap above and below it. The list
/// starts above the view by the top gap, so it is not seen over the first
/// bar. The pinned bar is not part of the
/// scrolling: it reads the scroll offset, finds the last bar that has reached
/// the top (`stickyAt`) and draws that day, pushed up by the next bar as it
/// arrives. What it covers is not hit (it is opaque, so a tap does not reach
/// a row under it), and the mouse wheel and touchpad scroll the list over it.
class HistoryTimelineView extends StatelessWidget {
  const HistoryTimelineView({
    super.key,
    required this.controller,
    required this.index,
    required this.rowsOf,
    required this.onTap,
    required this.onMenu,
    required this.onQueueAction,
    required this.playExtras,
    required this.onDayMenu,
    this.olderYear,
    this.onOlderYear,
  });

  final ScrollController controller;
  final HistoryTimelineIndex index;

  /// The plays of the day starting at the given epoch ms, null while unread.
  final List<HistoryPlayRow>? Function(int dayStart) rowsOf;

  /// A play was tapped: the play and the start of its day.
  final void Function(HistoryPlayRow row, int dayStart) onTap;

  /// A play's menu was asked for at the given global position.
  final void Function(HistoryPlayRow row, Offset position) onMenu;

  /// Queue action picked in the song modal of a row.
  final void Function(HistoryPlayRow row, QueueAction action) onQueueAction;

  /// Extras of the song modal of a row, built when it opens.
  final SongModalExtras Function(HistoryPlayRow row) playExtras;

  /// The menu button of a day's bar was pressed at the given global position.
  final void Function(HistoryDayCount day, Offset position) onDayMenu;

  /// The next older year with plays, offered at the end of the list.
  final int? olderYear;
  final VoidCallback? onOlderYear;

  Widget _bar(int day, double height) {
    final d = index.days[day];
    return HistoryDayBar(
      day: DateTime.fromMillisecondsSinceEpoch(d.dayStart),
      tracks: d.tracks,
      height: height,
      onMenu: (position) => onDayMenu(d, position),
    );
  }

  Widget _item(BuildContext context, int i, HistoryLineMetrics m) {
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
    if (row < 0) {
      return Padding(
        padding: EdgeInsets.only(top: m.topGap, bottom: m.bottomGap),
        child: _bar(day, m.bar),
      );
    }
    final dayStart = index.days[day].dayStart;
    final rows = rowsOf(dayStart);
    if (rows == null || row >= rows.length) return const SongTilePlaceholder();
    final play = rows[row];
    return HistoryPlayRowTile(
      key: ValueKey(play.id),
      row: play,
      onTap: () => onTap(play, dayStart),
      onMenu: (position) => onMenu(play, position),
      onQueueAction: (action) => onQueueAction(play, action),
      modalExtras: () => playExtras(play),
    );
  }

  /// The wheel and the touchpad over the pinned bar scroll the list, which is
  /// not under the pointer there. Linux touchpads send pan-zoom events, not
  /// scroll signals.
  void _scrollBy(double delta) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target != position.pixels) position.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final count = index.itemCount;
    if (count == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final m = HistoryLineMetrics.of(theme, scaler);
    final gap = m.topGap;
    return Stack(
      children: [
        // Starts [gap] above the view, clipped by the stack: the first header
        // line's gap is hidden, so the first bar sits at the top as a pinned
        // one does.
        Positioned(
          top: -gap,
          left: 0,
          right: 0,
          bottom: 0,
          child: ListView.builder(
            controller: controller,
            itemExtentBuilder: (i, _) => index.isHeader(i) ? m.header : m.line,
            itemCount: count,
            itemBuilder: (context, i) => _item(context, i, m),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: m.bar,
          child: ClipRect(
            key: historyStickyHeaderKey,
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _scrollBy(event.scrollDelta.dy);
                }
              },
              onPointerPanZoomUpdate: (event) => _scrollBy(-event.panDelta.dy),
              // The bar in the list is the one the screen reader and the
              // keyboard reach; this one is a copy over it.
              child: ExcludeSemantics(
                child: ExcludeFocus(
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final offset = controller.hasClients
                          ? controller.offset
                          : 0.0;
                      // The top of the view is [gap] into the list; at the
                      // start the first bar is in place, nothing to pin.
                      final sticky = offset <= 0
                          ? null
                          : index.stickyAt(offset + gap, m);
                      if (sticky == null) return const SizedBox.shrink();
                      return Transform.translate(
                        offset: Offset(0, sticky.dy),
                        child: _bar(sticky.day, m.bar),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
