import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';

import 'page_transition.dart';

/// Seed color used when the platform does not provide a dynamic one.
const kanaruSeedColor = Color(0xFF6750A4);

/// Builds the Material 3 theme. With a [coverSeed] (colors from the playing
/// cover) the scheme comes from it; otherwise from a dynamic [ColorScheme]
/// if the platform provides one, else from [kanaruSeedColor].
///
/// The result is cached by its inputs: a scheme is costly to compute and every
/// rebuild of the app shell asks for one, so the same inputs give the same
/// (identical) [ThemeData].
ThemeData buildTheme(
  ColorScheme? dynamicScheme,
  Brightness brightness, {
  Color? coverSeed,
}) {
  // The platform scheme is not used when a cover seed is, so it is not part
  // of the key then (a changed system accent must not duplicate entries).
  final key = (coverSeed == null ? dynamicScheme : null, brightness, coverSeed);
  final cached = _themeCache.remove(key);
  if (cached != null) return _themeCache[key] = cached;
  final theme = _buildTheme(dynamicScheme, brightness, coverSeed);
  _themeCache[key] = theme;
  // Insertion order is recency order: drop the least recently used.
  if (_themeCache.length > _themeCacheSize) {
    _themeCache.remove(_themeCache.keys.first);
  }
  return theme;
}

/// Themes kept: the current light and dark pair plus a few recent covers.
const _themeCacheSize = 8;

final _themeCache = <(ColorScheme?, Brightness, Color?), ThemeData>{};

ThemeData _buildTheme(
  ColorScheme? dynamicScheme,
  Brightness brightness,
  Color? coverSeed,
) {
  final colorScheme = coverSeed != null
      ? ColorScheme.fromSeed(seedColor: coverSeed, brightness: brightness)
      : dynamicScheme?.harmonized() ??
            ColorScheme.fromSeed(
              seedColor: kanaruSeedColor,
              brightness: brightness,
            );

  final base = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const SlideFromLeftPageTransitionsBuilder(),
      },
    ),
  );
  return base.copyWith(
    snackBarTheme: _snackBarTheme(colorScheme, base.textTheme),
  );
}

/// Every snackbar is a floating card on a surface container color, with a
/// close button. The default inverse surface is a dark full-width bar that
/// clashes with the page in both themes, so call sites never style their own.
SnackBarThemeData _snackBarTheme(ColorScheme colors, TextTheme textTheme) {
  return SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    width: 440,
    backgroundColor: colors.surfaceContainerHigh,
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    // Replaces the default style, so it is the full body style plus color.
    contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
    // The default inversePrimary is too faint on this surface.
    actionTextColor: colors.primary,
    closeIconColor: colors.onSurfaceVariant,
    showCloseIcon: true,
  );
}
