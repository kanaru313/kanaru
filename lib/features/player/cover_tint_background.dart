import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/cover_colors/cover_palette.dart';
import '../../core/cover_colors/playing_cover_palette_provider.dart';
import '../../shared/readable_gradient_stops.dart';

/// Stops in the Now Playing gradient, at most.
const _maxStops = maxGradientStops;

/// A background tinted with a gradient of the playing cover's colors, over
/// the theme's surface, when "colors from the cover" is on. Always opaque.
/// A new cover's gradient fades in over [coverThemeTransition], or at once
/// when the system asks for reduced motion.
///
/// The gradient is a translucent layer over the surface, so when the theme
/// jumps to the new cover's colors the surface changes at once and only the
/// tint fades; the tint does not restart its fade.
class CoverTintBackground extends ConsumerWidget {
  const CoverTintBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(appCoverPaletteProvider.select((p) => p?.colors));
    final scheme = Theme.of(context).colorScheme;
    final stops = colors == null
        ? List.filled(_maxStops, const Color(0x00000000))
        : _padded(
            readableGradientStops(
              colors,
              surface: scheme.surface,
              onSurface: scheme.onSurface,
              brightness: scheme.brightness,
            ),
          );
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: TweenAnimationBuilder<_Stops>(
              // The surface jumps at once on a light/dark switch; a fade from
              // the other brightness's stops could briefly break the text
              // contrast, so a new brightness starts at its own stops.
              key: ValueKey(scheme.brightness),
              tween: _StopsTween(end: _Stops(stops)),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : coverThemeTransition,
              curve: Curves.easeInOut,
              // Two layers: a BoxDecoration ignores its color once it has
              // a gradient, and the gradient is translucent.
              builder: (context, value, _) => ColoredBox(
                color: scheme.surface,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: value.colors,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// [stops] padded to [_maxStops] by repeating the last one, so two
/// gradients always tween stop by stop.
List<Color> _padded(List<Color> stops) => [
  for (var i = 0; i < _maxStops; i++) stops[math.min(i, stops.length - 1)],
];

/// A fixed-length list of gradient stops, comparable for the tween.
@immutable
class _Stops {
  const _Stops(this.colors);

  final List<Color> colors;

  @override
  bool operator ==(Object other) =>
      other is _Stops && listEquals(other.colors, colors);

  @override
  int get hashCode => Object.hashAll(colors);
}

class _StopsTween extends Tween<_Stops> {
  _StopsTween({super.end});

  @override
  _Stops lerp(double t) {
    final from = begin ?? end!, to = end!;
    return _Stops([
      for (var i = 0; i < _maxStops; i++)
        Color.lerp(
          _towards(from.colors[i], to.colors[i]),
          _towards(to.colors[i], from.colors[i]),
          t,
        )!,
    ]);
  }
}

/// A fully transparent [stop] takes [other]'s hue, so fading between a
/// cover and no colors changes only the opacity, never through a dark tint.
Color _towards(Color stop, Color other) =>
    stop.a == 0 ? other.withValues(alpha: 0) : stop;
