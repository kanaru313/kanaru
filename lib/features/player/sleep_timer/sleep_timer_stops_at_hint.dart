import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import 'sleep_timer_labels.dart';

/// "Stops at <time>" under the slider. It redraws every few seconds, so a
/// dialog left open does not show a stale clock.
class SleepTimerStopsAtHint extends StatefulWidget {
  const SleepTimerStopsAtHint({super.key, required this.minutes});

  final int minutes;

  @override
  State<SleepTimerStopsAtHint> createState() => _SleepTimerStopsAtHintState();
}

class _SleepTimerStopsAtHintState extends State<SleepTimerStopsAtHint> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    sleepTimerStopsAtText(
      context,
      context.l10n,
      Duration(minutes: widget.minutes),
    ),
  );
}
