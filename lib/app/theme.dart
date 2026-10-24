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

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const SlideFromLeftPageTransitionsBuilder(),
      },
    ),
  );
}
