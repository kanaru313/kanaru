import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// [current], or a new controller on the same tab when the tab change should
/// take another time: none while animations are off
/// ([MediaQuery.disableAnimationsOf]), the usual slide otherwise.
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
  if (current != null && current.animationDuration == duration) return current;
  final next = TabController(
    length: length,
    vsync: vsync,
    initialIndex: current?.index ?? 0,
    animationDuration: duration,
  )..addListener(onChanged);
  if (current != null) {
    current.removeListener(onChanged);
    SchedulerBinding.instance.addPostFrameCallback((_) => current.dispose());
  }
  return next;
}
