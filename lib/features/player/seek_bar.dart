import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/player_service.dart';
import '../../shared/format_duration.dart';
import 'seek_gesture_area.dart';
import 'seek_track_painter.dart';

/// Height of the track's hit area, roomy enough to hit without aiming.
const _hitHeight = 24.0;

/// Elapsed time · track · total time, under the playback controls. The track
/// is straight and follows playback in pixel-sized steps; nothing in the bar
/// animates on its own.
class SeekBar extends ConsumerWidget {
  const SeekBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The label shows whole seconds: the row rebuilds once a second, not on
    // every position tick.
    final (second, duration) = ref.watch(
      playerServiceProvider.select(
        (s) => (s.position.inSeconds, s.duration),
      ),
    );
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final colors = theme.colorScheme;

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
              ),
            ),
            Text(formatDuration(duration), style: style),
          ],
        ),
      ),
    );
  }
}
