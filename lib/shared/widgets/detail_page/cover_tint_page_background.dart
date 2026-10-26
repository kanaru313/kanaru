import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/cover_colors/cover_palette.dart';
import '../../../core/cover_colors/cover_palette_of_provider.dart';
import '../../../core/settings/settings_provider.dart';
import '../../readable_gradient_stops.dart';

/// Share of the readable tint the page shows: the full one, made for the
/// Now Playing screen, is too strong behind a list of rows.
const _tintStrength = 0.5;

/// Paints the background of a detail page (album, artist, genre) with a faint
/// gradient of the colors of its cover, faint enough that text keeps its
/// contrast, when "colors from the cover" is on. The default constructor tints
/// from one cover; [CoverTintPageBackground.blend] from the most common color
/// of each of several covers. Only the page is tinted here; the app theme
/// follows the playing track. Off, no cover, or no colors yet, leaves the page
/// as it was; the tint fades in once the colors of every cover are known.
class CoverTintPageBackground extends ConsumerWidget {
  CoverTintPageBackground({
    Key? key,
    required String? coverKey,
    required Widget child,
  }) : this.blend(key: key, coverKeys: [?coverKey], child: child);

  /// Tints from up to [maxGradientStops] of [coverKeys], in order.
  const CoverTintPageBackground.blend({
    super.key,
    required this.coverKeys,
    required this.child,
  });

  final List<String> coverKeys;
  final Widget child;

  /// The colors to tint with, or `null` while any cover is still loading, or
  /// when no cover has colors. One cover with colors gives all of them; several
  /// give the most common color of each.
  List<Color>? _tintColors(WidgetRef ref) {
    // Per cover: `null` until its palette first settles (a refresh that still
    // holds a value keeps it), empty once settled without colors.
    final settled = [
      for (final key in coverKeys.take(maxGradientStops))
        ref.watch(
          coverPaletteOfProvider(key).select(
            (p) => !p.hasValue && !p.hasError
                ? null
                : (p.value?.colors ?? const <Color>[]),
          ),
        ),
    ];
    if (settled.contains(null)) return null;
    final resolved = [
      for (final colors in settled)
        if (colors!.isNotEmpty) colors,
    ];
    return switch (resolved.length) {
      0 => null,
      1 => resolved.single,
      _ => [for (final colors in resolved) colors.first],
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(
      settingsProvider.select((s) => s.display.colorFromCover),
    );
    final colors = on ? _tintColors(ref) : null;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (colors != null)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _tintStrength),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : coverThemeTransition,
              builder: (context, t, child) => Opacity(opacity: t, child: child),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: readableGradientStops(
                      colors,
                      surface: scheme.surface,
                      onSurface: scheme.onSurface,
                      brightness: scheme.brightness,
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
