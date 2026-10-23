import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/player_service.dart';
import '../../core/player/track.dart';
import '../../l10n/l10n.dart';
import '../../shared/format_duration.dart';
import 'seek_follow_step.dart';

/// Keyboard and assistive-tech seek step.
const _step = Duration(seconds: 5);

/// What a seek track draws: the progress to show (the pointer while
/// dragging), the track's width, whether it is hovered or dragged, and
/// whether it is dragged.
typedef SeekTrackState = ({
  double progress,
  double width,
  bool active,
  bool dragging,
});

/// Seek interaction shared by every progress bar: click or drag to seek,
/// the target time in a bubble above the pointer, a slider for assistive
/// tech. [builder] draws the track inside a [height] tall hit area.
class SeekGestureArea extends ConsumerStatefulWidget {
  const SeekGestureArea({
    super.key,
    required this.height,
    required this.builder,
  });

  final double height;
  final Widget Function(BuildContext context, SeekTrackState state) builder;

  @override
  ConsumerState<SeekGestureArea> createState() => _SeekGestureAreaState();
}

class _SeekGestureAreaState extends ConsumerState<SeekGestureArea> {
  final _label = OverlayPortalController();
  final _link = LayerLink();
  bool _hovered = false;

  /// Pointer position as a fraction of the width while hovering/dragging.
  double? _pointer;
  bool _dragging = false;

  /// Track being dragged on, with its queue position: a drag that outlives
  /// the track does not seek the next one.
  (int, Track?)? _draggedTrack;

  (int, Track?) _playingTrack() {
    final queue = ref.read(playerServiceProvider).queue;
    return (queue.index, queue.current);
  }

  double _fraction(Offset local, double width) =>
      (local.dx / width).clamp(0.0, 1.0);

  void _point(double? fraction) {
    setState(() => _pointer = fraction);
    fraction == null ? _label.hide() : _label.show();
  }

  void _seekTo(double fraction, Duration duration) {
    ref.read(playerServiceProvider.notifier).seek(duration * fraction);
  }

  void _endDrag() {
    _dragging = false;
    _draggedTrack = null;
    _point(_hovered ? _pointer : null);
  }

  @override
  Widget build(BuildContext context) {
    // Whole seconds are all the spoken value shows, so only a change of the
    // second rebuilds this; the thumb follows in [Consumer] below, in steps.
    final (second, duration) = ref.watch(
      playerServiceProvider.select((s) => (s.position.inSeconds, s.duration)),
    );
    final position = Duration(seconds: second);
    final player = ref.read(playerServiceProvider.notifier);
    final enabled = duration > Duration.zero;
    String spoken(Duration at) {
      final clamped = at < Duration.zero
          ? Duration.zero
          : (at > duration ? duration : at);
      return '${formatDuration(clamped)} / ${formatDuration(duration)}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final step = seekFollowStep(duration, width);
        return Semantics(
          slider: true,
          label: context.l10n.playerSeek,
          value: spoken(position),
          increasedValue: enabled ? spoken(position + _step) : null,
          decreasedValue: enabled ? spoken(position - _step) : null,
          onIncrease: enabled ? () => player.seekBy(_step) : null,
          onDecrease: enabled ? () => player.seekBy(-_step) : null,
          child: CompositedTransformTarget(
            link: _link,
            child: OverlayPortal(
              controller: _label,
              overlayChildBuilder: (context) => _SeekTimeBubble(
                link: _link,
                x: (_pointer ?? 0) * width,
                width: width,
                text: formatDuration(duration * (_pointer ?? 0)),
              ),
              child: MouseRegion(
                cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
                onEnter: (_) => setState(() => _hovered = true),
                onHover: enabled
                    ? (e) => _point(_fraction(e.localPosition, width))
                    : null,
                onExit: (_) {
                  setState(() => _hovered = false);
                  if (!_dragging) _point(null);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: enabled
                      ? (e) =>
                            _seekTo(_fraction(e.localPosition, width), duration)
                      : null,
                  // Always attached, checking [enabled] inside: a recognizer
                  // dropped mid-drag (the track changed and the duration
                  // went to zero) would never report the end of the drag.
                  onHorizontalDragStart: (e) {
                    if (!enabled) return;
                    _dragging = true;
                    _draggedTrack = _playingTrack();
                    _point(_fraction(e.localPosition, width));
                  },
                  onHorizontalDragUpdate: (e) {
                    if (_dragging) _point(_fraction(e.localPosition, width));
                  },
                  onHorizontalDragEnd: (_) {
                    final pointer = _pointer;
                    if (_dragging &&
                        enabled &&
                        pointer != null &&
                        _draggedTrack == _playingTrack()) {
                      _seekTo(pointer, duration);
                    }
                    _endDrag();
                  },
                  onHorizontalDragCancel: _endDrag,
                  child: SizedBox(
                    height: widget.height,
                    // The only part that follows playback in [step]s: a
                    // position tick inside a step builds nothing.
                    child: Consumer(
                      builder: (context, ref, _) {
                        final shown = ref.watch(
                          playerServiceProvider.select(
                            (s) => seekShownPosition(s.position, step),
                          ),
                        );
                        final progress = !enabled
                            ? 0.0
                            : (_dragging && _pointer != null
                                  ? _pointer!
                                  : (shown.inMicroseconds /
                                            duration.inMicroseconds)
                                        .clamp(0.0, 1.0));
                        return widget.builder(context, (
                          progress: progress,
                          width: width,
                          active: enabled && (_hovered || _dragging),
                          dragging: _dragging,
                        ));
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Time bubble that floats above the track at [x], kept inside [width].
class _SeekTimeBubble extends StatelessWidget {
  const _SeekTimeBubble({
    required this.link,
    required this.x,
    required this.width,
    required this.text,
  });

  /// Room kept between the bubble's center and the track's ends; about half
  /// the width of `h:mm:ss` in the label font.
  static const _edge = 32.0;

  final LayerLink link;
  final double x;
  final double width;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = width > 2 * _edge ? x.clamp(_edge, width - _edge) : x;
    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: link,
        offset: Offset(center, -4),
        followerAnchor: Alignment.bottomCenter,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                text,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onInverseSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
