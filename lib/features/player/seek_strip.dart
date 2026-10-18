import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/player_service.dart';
import '../../l10n/l10n.dart';
import 'format_duration.dart';

/// Height of the strip's hit area. The bar, grown or not, and the thumb all
/// stay inside it, so every visible part takes clicks.
const seekStripHitHeight = 12.0;

/// The bar keeps this bottom edge and grows upwards from it.
const _barBottom = 8.0;
const _thinBar = 2.0;
const _thickBar = 6.0;
const _thumbSize = 10.0;
const _animation = Duration(milliseconds: 120);

/// Keyboard and assistive-tech seek step.
const _step = Duration(seconds: 5);

/// Thin progress bar along the player bar's top edge, doubling as its
/// border. On hover it grows upwards and shows a round thumb at the playback
/// point; click or drag to seek, with the target time shown above the
/// pointer.
class SeekStrip extends ConsumerStatefulWidget {
  const SeekStrip({super.key});

  @override
  ConsumerState<SeekStrip> createState() => _SeekStripState();
}

class _SeekStripState extends ConsumerState<SeekStrip> {
  final _label = OverlayPortalController();
  final _link = LayerLink();
  bool _hovered = false;

  /// Pointer position as a fraction of the width while hovering/dragging.
  double? _pointer;
  bool _dragging = false;

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
    _point(_hovered ? _pointer : null);
  }

  @override
  Widget build(BuildContext context) {
    final (position, duration) = ref.watch(
      playerServiceProvider.select((s) => (s.position, s.duration)),
    );
    final player = ref.read(playerServiceProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final enabled = duration > Duration.zero;
    final progress = enabled
        ? (_dragging && _pointer != null
              ? _pointer!
              : (position.inMilliseconds / duration.inMilliseconds).clamp(
                  0.0,
                  1.0,
                ))
        : 0.0;
    final thick = enabled && (_hovered || _dragging);
    String spoken(Duration at) {
      final clamped = at < Duration.zero
          ? Duration.zero
          : (at > duration ? duration : at);
      return '${formatDuration(clamped)} / ${formatDuration(duration)}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
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
                  onHorizontalDragStart: enabled
                      ? (e) {
                          _dragging = true;
                          _point(_fraction(e.localPosition, width));
                        }
                      : null,
                  onHorizontalDragUpdate: enabled
                      ? (e) => _point(_fraction(e.localPosition, width))
                      : null,
                  onHorizontalDragEnd: enabled
                      ? (_) {
                          if (_pointer != null) _seekTo(_pointer!, duration);
                          _endDrag();
                        }
                      : null,
                  onHorizontalDragCancel: enabled ? _endDrag : null,
                  child: SizedBox(
                    height: seekStripHitHeight,
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: _animation,
                          left: 0,
                          right: 0,
                          top: _barBottom - (thick ? _thickBar : _thinBar),
                          height: thick ? _thickBar : _thinBar,
                          child: ColoredBox(
                            color: colors.outlineVariant,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: progress,
                                heightFactor: 1,
                                child: ColoredBox(color: colors.primary),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          // Kept inside the window at both ends.
                          left: (progress * width - _thumbSize / 2).clamp(
                            0.0,
                            width - _thumbSize,
                          ),
                          top: _barBottom - _thickBar / 2 - _thumbSize / 2,
                          child: AnimatedScale(
                            duration: _animation,
                            scale: thick ? 1 : 0,
                            child: Container(
                              width: _thumbSize,
                              height: _thumbSize,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
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

/// Time bubble that floats above the strip at [x], kept inside [width].
class _SeekTimeBubble extends StatelessWidget {
  const _SeekTimeBubble({
    required this.link,
    required this.x,
    required this.width,
    required this.text,
  });

  /// Room kept between the bubble's center and the window edges; about half
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
