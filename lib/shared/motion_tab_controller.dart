import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// [current], or a new controller on the same tab when the tab change should
/// take another time: none while animations are off
/// ([MediaQuery.disableAnimationsOf]), the usual slide otherwise. A different
/// [length] also gives a new controller, which keeps the current tab's index
/// or, when that no longer exists, the last one.
///
/// A [TabController] cannot change its duration, so it is replaced. The old
/// one loses [onChanged] at once and is disposed after the frame, once the
/// tab bar has moved to the new one; [vsync] must therefore allow several
/// tickers. Call from `didChangeDependencies`, which runs again when the
/// setting changes.
TabController motionTabController(
  BuildContext context, {
  required TabController? current,
  required int length,
  required TickerProvider vsync,
  required VoidCallback onChanged,
}) {
  final duration = MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : kTabScrollDuration;
  if (current != null &&
      current.animationDuration == duration &&
      current.length == length) {
    return current;
  }
  final next = TabController(
    length: length,
    vsync: vsync,
    initialIndex: math.min(current?.index ?? 0, length - 1),
    animationDuration: duration,
  )..addListener(onChanged);
  if (current != null) {
    current.removeListener(onChanged);
    SchedulerBinding.instance.addPostFrameCallback((_) => current.dispose());
  }
  return next;
}
