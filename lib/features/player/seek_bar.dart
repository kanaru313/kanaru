import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/player_service.dart';
import '../../shared/format_duration.dart';
import 'seek_gesture_area.dart';
import 'wavy_track_painter.dart';

/// Height of the track's hit area, roomy enough to hit without aiming.
const _hitHeight = 24.0;

/// How long the wave takes to rise when playback starts, or to settle when
/// it stops.
const _waveRise = Duration(milliseconds: 300);

/// How long one full wave takes to travel its own length.
const _waveTravel = Duration(milliseconds: 1500);

/// How often the travelling wave moves on: about 15 times a second. On GTK
/// each frame composites the whole window, so a wave drawn at the display's
/// rate (60 a second) costs about four times as much for a motion that looks
/// the same on a 4 px thick line.
const _waveFrame = Duration(milliseconds: 66);

/// Elapsed time · track · total time, under the playback controls. While
/// music plays the played part of the track turns into a travelling wave;
/// it lies flat when paused, while dragging, with animations turned off, or
/// while the window is not focused.
class SeekBar extends ConsumerWidget {
  const SeekBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The label shows whole seconds: the row rebuilds once a second, not on
    // every position tick.
    final (second, duration, playing) = ref.watch(
      playerServiceProvider.select(
        (s) => (s.position.inSeconds, s.duration, s.playing),
      ),
    );
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // The row is as high as its tallest part: the track or a time label.
    final labelHeight = MediaQuery.textScalerOf(context)
        .scale((style?.fontSize ?? 12) * (style?.height ?? 1));

    // Position ticks repaint only this row. Its size is fixed so that their
    // layout does not reach what surrounds it either.
    return SizedBox(
      width: double.infinity,
      height: math.max(_hitHeight, labelHeight),
      child: RepaintBoundary(
        child: Row(
          spacing: 8,
          children: [
            Text(formatDuration(Duration(seconds: second)), style: style),
            Expanded(
              child: SeekGestureArea(
                height: _hitHeight,
                builder: (context, state) => _WavyTrack(
                  progress: state.progress,
                  waving:
                      playing &&
                      duration > Duration.zero &&
                      !state.dragging &&
                      !reduceMotion,
                ),
              ),
            ),
            Text(formatDuration(duration), style: style),
          ],
        ),
      ),
    );
  }
}

/// Owns the wave's animations: they run only while the wave moves or
/// settles, and stop once it lies flat. The wave moves only while the app is
/// `resumed` and the widget is not muted by a covering screen
/// ([TickerMode], as Now Playing does to the shell under it): an unfocused or
/// minimized window lets it settle, a covered one stops at once.
///
/// The amplitude rises and settles on a vsync-driven controller, which asks
/// for a frame only while it runs. The phase moves on a timer instead, a
/// [_waveFrame] at a time: a ticker would ask for a frame on every vsync
/// whether or not the phase changed.
class _WavyTrack extends StatefulWidget {
  const _WavyTrack({required this.progress, required this.waving});

  final double progress;
  final bool waving;

  @override
  State<_WavyTrack> createState() => _WavyTrackState();
}

class _WavyTrackState extends State<_WavyTrack>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _amplitude = AnimationController(vsync: this, duration: _waveRise);

  /// Where the wave is in its travel, from 0 to 1.
  final _phase = ValueNotifier<double>(0);

  /// Moves [_phase] on; running only while the wave travels.
  Timer? _travel;

  /// Timer ticks made so far. The phase is counted from them, not read from
  /// a clock, so it does not depend on how late a tick fired.
  int _steps = 0;

  /// Whether the window has focus. Unknown counts as focused.
  bool _focused = _isFocused(WidgetsBinding.instance.lifecycleState);

  static bool _isFocused(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Runs once after [initState] and again when [TickerMode] changes.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final focused = _isFocused(state);
    if (focused == _focused) return;
    _focused = focused;
    _sync();
  }

  @override
  void didUpdateWidget(_WavyTrack old) {
    super.didUpdateWidget(old);
    if (old.waving != widget.waving) _sync();
  }

  void _sync() {
    final visible = TickerMode.valuesOf(context).enabled;
    if (widget.waving && _focused && visible) {
      _amplitude.forward();
      _startTravel();
      return;
    }
    // A covered wave is muted: its amplitude cannot settle, and nothing may
    // keep drawing under the covering screen.
    if (!visible) _stopTravel();
    // Keeps travelling while it flattens, then stops for good. Waving again
    // before then cancels the flattening, and the wave keeps going. A wave
    // uncovered mid-settle travels on for the rest of it.
    if (visible && !_amplitude.isDismissed) _startTravel();
    _amplitude.reverse().whenCompleteOrCancel(() {
      if (mounted && _amplitude.isDismissed) _stopTravel();
    });
  }

  void _startTravel() {
    _travel ??= Timer.periodic(_waveFrame, (_) => _step());
  }

  void _step() {
    _steps++;
    _phase.value =
        (_steps * _waveFrame.inMicroseconds % _waveTravel.inMicroseconds) /
        _waveTravel.inMicroseconds;
  }

  void _stopTravel() {
    _travel?.cancel();
    _travel = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTravel();
    _amplitude.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: WavyTrackPainter(
          progress: widget.progress,
          amplitude: _amplitude,
          phase: _phase,
          playedColor: colors.primary,
          restColor: colors.secondaryContainer,
        ),
      ),
    );
  }
}
