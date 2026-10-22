import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';

import 'page_transition.dart';

/// Seed color used when the platform does not provide a dynamic one.
const kanaruSeedColor = Color(0xFF6750A4);

/// How long the app takes to move to the colors of a new cover (and between
/// light and dark). Zero when the system asks for reduced motion.
const coverThemeTransition = Duration(milliseconds: 300);

/// Builds the Material 3 theme. With a [coverSeed] (colors from the playing
/// cover) the scheme comes from it; otherwise from a dynamic [ColorScheme]
/// if the platform provides one, else from [kanaruSeedColor].
ThemeData buildTheme(
  ColorScheme? dynamicScheme,
  Brightness brightness, {
  Color? coverSeed,
}) {
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
          platform: const SlideUpPageTransitionsBuilder(),
      },
    ),
  );
}
