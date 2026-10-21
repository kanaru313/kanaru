import 'package:material_ui/material_ui.dart';

import 'seek_gesture_area.dart';

/// Height of the strip's hit area. The bar, grown or not, and the thumb all
/// stay inside it, so every visible part takes clicks.
const seekStripHitHeight = 12.0;

/// The bar keeps this bottom edge and grows upwards from it.
const _barBottom = 8.0;
const _thinBar = 2.0;
const _thickBar = 6.0;
const _thumbSize = 10.0;
const _animation = Duration(milliseconds: 120);

/// Thin progress bar along the player bar's top edge, doubling as its
/// border; used where the bar has no room for a `SeekBar` row. On hover it
/// grows upwards and shows a round thumb at the playback point.
class SeekStrip extends StatelessWidget {
  const SeekStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Position ticks repaint only the strip, not the bar under it. The fixed
    // height keeps their layout from reaching the bar either.
    return SizedBox(
      height: seekStripHitHeight,
      child: RepaintBoundary(
        child: SeekGestureArea(
          height: seekStripHitHeight,
          builder: (context, state) {
            final thick = state.active;
            return Stack(
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
                        widthFactor: state.progress,
                        heightFactor: 1,
                        child: ColoredBox(color: colors.primary),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  // Kept inside the window at both ends.
                  left: (state.progress * state.width - _thumbSize / 2).clamp(
                    0.0,
                    state.width - _thumbSize,
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
            );
          },
        ),
      ),
    );
  }
}
