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

/// Elapsed time · track · total time, under the playback controls. While
/// music plays the played part of the track turns into a travelling wave;
/// it lies flat when paused, while dragging, with animations turned off, or
/// while the window is not focused.
class SeekBar extends ConsumerWidget {
  const SeekBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (position, duration, playing) = ref.watch(
      playerServiceProvider.select((s) => (s.position, s.duration, s.playing)),
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
            Text(formatDuration(position), style: style),
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

/// Owns the wave's animations: they tick only while the wave moves or
/// settles, and stop once it lies flat. The wave moves only while the app is
/// `resumed`: an unfocused or minimized window lets it settle.
class _WavyTrack extends StatefulWidget {
  const _WavyTrack({required this.progress, required this.waving});

  final double progress;
  final bool waving;

  @override
  State<_WavyTrack> createState() => _WavyTrackState();
}

class _WavyTrackState extends State<_WavyTrack>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final _amplitude = AnimationController(vsync: this, duration: _waveRise);
  late final _phase = AnimationController(vsync: this, duration: _waveTravel);

  /// Whether the window has focus. Unknown counts as focused.
  bool _focused = _isFocused(WidgetsBinding.instance.lifecycleState);

  static bool _isFocused(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    if (widget.waving && _focused) {
      _amplitude.forward();
      if (!_phase.isAnimating) _phase.repeat();
      return;
    }
    // Keeps travelling while it flattens, then stops for good. Waving again
    // before then cancels the flattening, and the wave keeps going.
    _amplitude.reverse().whenCompleteOrCancel(() {
      if (mounted && _amplitude.isDismissed) _phase.stop();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
