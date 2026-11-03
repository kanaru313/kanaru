import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/history_queries.dart';
import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../shared/play_tracks.dart';
import 'day_modal/open_history_day_modal.dart';
import 'history_day_queue.dart';

/// What the timeline does with a tap and a day menu. The state of
/// the timeline body provides the rows ([rowsOfDay], [loadDay]).
mixin HistoryTimelineActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// The rows of the day starting at [dayStart] when they are loaded.
  List<HistoryPlayRow>? rowsOfDay(int dayStart);

  /// Reads the plays of the day starting at [dayStart], cut to the count the
  /// page shows for it.
  Future<List<HistoryPlayRow>> loadDay(int dayStart);

  /// A Day modal is being opened: a second click on the button while the
  /// first read is under way must not open another one.
  bool _dayMenuBusy = false;

  void playFromRow(HistoryPlayRow row, int dayStart) {
    final queue = historyDayQueue(
      rowsOfDay(dayStart) ?? [row],
      row,
      ref.read(coverCacheDirectoryProvider),
    );
    if (queue != null) playTracks(ref, queue.tracks, queue.start);
  }

  Future<void> openDayMenu(
    HistoryDayCount day, {
    required bool viaKeyboard,
  }) async {
    if (_dayMenuBusy) return;
    _dayMenuBusy = true;
    try {
      await openHistoryDayModal(
        ref,
        context,
        day: DateTime.fromMillisecondsSinceEpoch(day.dayStart),
        readDay: () => loadDay(day.dayStart),
        viaKeyboard: viaKeyboard,
      );
    } finally {
      _dayMenuBusy = false;
    }
  }
}
