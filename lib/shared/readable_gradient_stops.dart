import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Stops [readableGradientStops] gives, at most.
const maxGradientStops = 4;

/// WCAG contrast the page's text keeps against every stop.
const _minContrast = 4.5;

/// Tint of the cover colors over the surface, before any lowering for
/// contrast.
const _darkTint = 0.45, _lightTint = 0.35, _tintStep = 0.05;

/// Translucent gradient stops of a cover's [palette], to paint over
/// [surface], each faint enough that [onSurface] text on the blend keeps a
/// contrast of at least 4.5:1: the tint starts at 0.45 (dark) or 0.35
/// (light) and drops in 0.05 steps until the contrast holds (down to fully
/// transparent). Two to four stops: one color gives itself and a shade of it
/// toward the surface.
List<Color> readableGradientStops(
  List<Color> palette, {
  required Color surface,
  required Color onSurface,
  required Brightness brightness,
}) {
  if (palette.isEmpty) return const [Color(0x00000000), Color(0x00000000)];
  final dark = brightness == Brightness.dark;
  final colors = palette.length == 1
      ? [palette.first, _shade(palette.first, dark)]
      : palette.take(maxGradientStops).toList();
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
    final tint = color.withValues(alpha: alpha);
    if (_contrast(onSurface, Color.alphaBlend(tint, surface)) >= _minContrast) {
      return tint;
    }
  }
  return color.withValues(alpha: 0);
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
