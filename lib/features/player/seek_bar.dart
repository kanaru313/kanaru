import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/player_service.dart';
import '../../shared/format_duration.dart';
import 'seek_gesture_area.dart';
import 'seek_track_painter.dart';

/// Height of the track's hit area, roomy enough to hit without aiming.
const seekHitHeight = 24.0;

/// Elapsed time · track · total time, under the playback controls. The track
/// is straight and follows playback in pixel-sized steps; nothing in the bar
/// animates on its own. [track] can be swapped for another seek visual.
class SeekBar extends StatelessWidget {
  const SeekBar({super.key, this.track = const SeekTrack()});

  /// What sits between the two time labels; it should handle seeking itself.
  final Widget track;

  @override
  Widget build(BuildContext context) {
    // The row is as high as its tallest part: the track or a time label.
    final labelStyle = _labelStyle(context);
    final labelHeight = MediaQuery.textScalerOf(context)
        .scale((labelStyle?.fontSize ?? 12) * (labelStyle?.height ?? 1));

    // Position ticks repaint only the labels and the track, each in its own
    // boundary. The row's size is fixed so that their layout does not reach
    // what surrounds it either.
    return SizedBox(
      width: double.infinity,
      height: math.max(seekHitHeight, labelHeight),
      // The outer boundary keeps the gesture area's own repaints (hover
      // bubble, semantics) inside the row too.
      child: RepaintBoundary(
        child: Row(
          spacing: 8,
          children: [
            const SeekElapsedLabel(),
            Expanded(child: track),
            const SeekDurationLabel(),
          ],
        ),
      ),
    );
  }
}

TextStyle? _labelStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// The playback position in whole seconds: rebuilds once a second, not on
/// every position tick.
class SeekElapsedLabel extends ConsumerWidget {
  const SeekElapsedLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final second = ref.watch(
      playerServiceProvider.select((s) => s.position.inSeconds),
    );
    return RepaintBoundary(
      child: Text(
        formatDuration(Duration(seconds: second)),
        style: _labelStyle(context),
      ),
    );
  }
}

/// The length of the playing track.
class SeekDurationLabel extends ConsumerWidget {
  const SeekDurationLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = ref.watch(playerServiceProvider.select((s) => s.duration));
    return RepaintBoundary(
      child: Text(formatDuration(duration), style: _labelStyle(context)),
    );
  }
}

/// The straight seek track: click or drag to seek, painted in follow steps.
class SeekTrack extends StatelessWidget {
  const SeekTrack({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SeekGestureArea(
      height: seekHitHeight,
      builder: (context, state) => RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: SeekTrackPainter(
            progress: state.progress,
            playedColor: colors.primary,
            restColor: colors.secondaryContainer,
          ),
        ),
      ),
    );
  }
}
