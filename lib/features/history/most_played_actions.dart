import 'package:flutter/widgets.dart' show BuildContext, Widget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/context_menu_more_button.dart';
import 'history_top_queue.dart';
import 'most_played_modal/open_most_played_modal.dart';

/// Plays the songs of [rows] that can play, in rank order, from the first.
void playMostPlayed(WidgetRef ref, List<HistoryTopRow> rows) => playTracks(
  ref,
  historyTopPlayable(rows, ref.read(coverCacheDirectoryProvider)),
  0,
);

/// Shuffles the songs of [rows] that can play into the queue.
void shuffleMostPlayed(WidgetRef ref, List<HistoryTopRow> rows) =>
    shuffleTracks(
      ref,
      historyTopPlayable(rows, ref.read(coverCacheDirectoryProvider)),
    );

/// The ⋮ next to Play and Shuffle: opens the Most played modal on [rows].
/// Off while no listed song can play, and while [stale]: the next range is
/// loading or its read failed, so [rows] are the last range's and the modal
/// would pair them with the new [rangeText].
Widget mostPlayedMoreButton(
  WidgetRef ref,
  BuildContext context, {
  required List<HistoryTopRow>? rows,
  required String rangeText,
  required HistoryRangeSummary? totals,
  required bool stale,
}) => ContextMenuMoreButton(
  enabled: !stale && (rows?.any((r) => r.track != null) ?? false),
  onOpen: ({required viaKeyboard, required at}) => openMostPlayedModal(
    ref,
    context,
    rows: rows ?? const [],
    rangeText: rangeText,
    totals: totals,
    viaKeyboard: viaKeyboard,
  ),
);
