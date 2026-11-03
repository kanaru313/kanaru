import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../core/stats/listen_clear_scope.dart';

/// The Undo snackbar shown or waiting behind other messages.
class UndoMessage {
  UndoMessage(this.plays, this.messenger) : count = ValueNotifier(plays.length);

  /// Every play removed since the first snackbar of this run appeared: what
  /// Undo puts back.
  final List<Play> plays;

  /// Length of [plays], for the title of a snackbar that is still waiting.
  final ValueNotifier<int> count;
  final ScaffoldMessengerState messenger;
  late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  controller;

  /// The snackbar finished appearing, so its time on screen is running and new
  /// plays could not get a time of their own.
  bool visible = false;
  bool closed = false;

  /// Undo was pressed. The snackbar may still be leaving, but its plays are
  /// already restored, so a later removal must not carry them again.
  bool undone = false;

  /// Drops the plays [bounds] cleared; the Undo of an emptied message does
  /// nothing.
  void dropCleared(ClearBounds bounds) {
    plays.removeWhere((p) => boundsCover(bounds, p.playedAt));
    count.value = plays.length;
  }

  void add(List<Play> more) {
    final merged = mergePlaysById(plays, more);
    plays
      ..clear()
      ..addAll(merged);
    count.value = plays.length;
  }
}

/// [first] then [second] without repeats of a play id, in order.
List<Play> mergePlaysById(List<Play> first, List<Play> second) => [
  ...{
    for (final p in [...first, ...second]) p.id: p,
  }.values,
];
