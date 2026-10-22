import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart' show coverThemeTransition;
import '../../../core/cover_colors/playing_cover_palette_provider.dart';

/// Stops in the Now Playing gradient, at most.
const _maxStops = 4;

/// WCAG contrast the page's text keeps against every stop.
const _minContrast = 4.5;

/// Tint of the cover colors over the surface, before any lowering for
/// contrast.
const _darkTint = 0.45, _lightTint = 0.35, _tintStep = 0.05;

/// The Now Playing background: the theme's surface, tinted with a gradient
/// of the playing cover's colors when "colors from the cover" is on. Always
/// opaque (the shell lies under Now Playing). A new cover's gradient fades in
/// over [coverThemeTransition], or at once when the system asks for reduced
/// motion.
class NowPlayingCoverGradient extends ConsumerWidget {
  const NowPlayingCoverGradient({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(appCoverPaletteProvider.select((p) => p?.colors));
    final scheme = Theme.of(context).colorScheme;
    final stops = colors == null
        ? List.filled(_maxStops, scheme.surface)
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
              tween: _StopsTween(end: _Stops(stops)),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : coverThemeTransition,
              curve: Curves.easeInOut,
              builder: (context, value, _) => DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
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
        child,
      ],
    );
  }
}

/// Opaque gradient stops from a cover's [palette] over [surface], each faint
/// enough that [onSurface] text keeps a contrast of at least 4.5:1: the
/// tint starts at 0.45 (dark) or 0.35 (light) and drops in 0.05 steps until
/// the contrast holds (down to the bare surface). Two to four stops: one
/// color gives itself and a shade of it toward the surface.
List<Color> readableGradientStops(
  List<Color> palette, {
  required Color surface,
  required Color onSurface,
  required Brightness brightness,
}) {
  if (palette.isEmpty) return [surface, surface];
  final dark = brightness == Brightness.dark;
  final colors = palette.length == 1
      ? [palette.first, _shade(palette.first, dark)]
      : palette.take(_maxStops).toList();
  final opaqueSurface = surface.withValues(alpha: 1);
  return [
    for (final color in colors)
      _readableTint(
        color,
        opaqueSurface,
        onSurface,
        dark ? _darkTint : _lightTint,
      ),
  ];
}

Color _readableTint(Color color, Color surface, Color onSurface, double start) {
  for (var alpha = start; alpha > 0; alpha -= _tintStep) {
    final stop = Color.alphaBlend(color.withValues(alpha: alpha), surface);
    if (_contrast(onSurface, stop) >= _minContrast) return stop;
  }
  return surface;
}

/// [color] 12 points (of 100) of lightness toward the surface: darker on a
/// dark theme, lighter on a light one, so a one-color gradient fades out.
Color _shade(Color color, bool dark) {
  final hsl = HSLColor.fromColor(color);
  final lightness = (hsl.lightness + (dark ? -0.12 : 0.12)).clamp(0.0, 1.0);
  return hsl.withLightness(lightness).toColor();
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
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
        Color.lerp(from.colors[i], to.colors[i], t)!,
    ]);
  }
}
