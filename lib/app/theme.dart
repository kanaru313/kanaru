import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';

/// Seed color used when the platform does not provide a dynamic one.
const kanaruSeedColor = Color(0xFF6750A4);

/// Builds the Material 3 theme from a dynamic [ColorScheme] if the platform
/// provides one, otherwise from [kanaruSeedColor].
ThemeData buildTheme(ColorScheme? dynamicScheme, Brightness brightness) {
  final colorScheme =
      dynamicScheme?.harmonized() ??
      ColorScheme.fromSeed(seedColor: kanaruSeedColor, brightness: brightness);

  return ThemeData(colorScheme: colorScheme, useMaterial3: true);
}
