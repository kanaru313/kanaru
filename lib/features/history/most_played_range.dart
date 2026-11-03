import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'history_range.dart';

/// The range the Most played page shows. One source for the range bar, the
/// custom range picker and "Open in Most played" (the Day modal), kept alive
/// so the range survives a switch to another page and a remount of the view.
final mostPlayedRangeProvider =
    NotifierProvider<MostPlayedRangeNotifier, HistoryRangeState>(
      MostPlayedRangeNotifier.new,
    );

class MostPlayedRangeNotifier extends Notifier<HistoryRangeState> {
  @override
  HistoryRangeState build() => const HistoryRangeState();

  /// Shows exactly [range].
  void set(HistoryRangeState range) => state = range;

  /// Shows [preset] at its current period; a custom range stays remembered.
  void withPreset(HistoryRangePreset preset) =>
      state = state.withPreset(preset);

  /// The period before the one on show.
  void previous() => state = state.previous();

  /// The period after the one on show.
  void next() => state = state.next();
}
