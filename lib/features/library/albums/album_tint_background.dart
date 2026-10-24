import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/cover_colors/cover_palette.dart';
import '../../../core/cover_colors/cover_palette_of_provider.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../shared/readable_gradient_stops.dart';

/// Share of the readable tint the page shows: the full one, made for the
/// Now Playing screen, is too strong behind a list of rows.
const _tintStrength = 0.5;

/// Paints the album page's own background with a faint gradient of the
/// album cover's colors, faint enough that text keeps its contrast, when
/// "colors from the cover" is on. Only the page is tinted here; the app
/// theme follows the playing track. Off, no cover, or no colors yet,
/// leaves the page as it was; the tint fades in once the colors are known.
class AlbumTintBackground extends ConsumerWidget {
  const AlbumTintBackground({
    super.key,
    required this.coverKey,
    required this.child,
  });

  final String? coverKey;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(
      settingsProvider.select((s) => s.display.colorFromCover),
    );
    final key = on ? coverKey : null;
    final colors = key == null
        ? null
        : ref.watch(coverPaletteOfProvider(key).select((p) => p.value?.colors));
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
