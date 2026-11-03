import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_color_utilities/material_color_utilities.dart'
    show Cam16, Hct;
import 'package:material_ui/material_ui.dart';

import 'page_transition.dart';

/// Seed color used when the platform does not provide a dynamic one. It is the
/// logo wedge color; as a tonal-spot seed only its hue counts, and the dark
/// primary equals it.
const kanaruSeedColor = Color(0xFFFFB4A2);

/// Builds the Material 3 theme. With a [coverSeed] (colors from the playing
/// cover) the scheme comes from it; otherwise from a dynamic [ColorScheme]
/// if the platform provides one, else from [kanaruSeedColor].
///
/// In dark mode an error color too close to the primary is replaced (see
/// [_withDistinctError]).
///
/// The result is cached by its inputs: a scheme is costly to compute and every
/// rebuild of the app shell asks for one, so the same inputs give the same
/// (identical) [ThemeData].
ThemeData buildTheme(
  ColorScheme? dynamicScheme,
  Brightness brightness, {
  Color? coverSeed,
  required String? fontFamily,
}) {
  // The platform scheme is not used when a cover seed is, so it is not part
  // of the key then (a changed system accent must not duplicate entries).
  final key = (
    coverSeed == null ? dynamicScheme : null,
    brightness,
    coverSeed,
    fontFamily,
  );
  final cached = _themeCache.remove(key);
  if (cached != null) return _themeCache[key] = cached;
  final theme = _buildTheme(dynamicScheme, brightness, coverSeed, fontFamily);
  _themeCache[key] = theme;
  // Insertion order is recency order: drop the least recently used.
  if (_themeCache.length > _themeCacheSize) {
    _themeCache.remove(_themeCache.keys.first);
  }
  return theme;
}

/// Themes kept: the current light and dark pair plus a few recent covers.
const _themeCacheSize = 8;

final _themeCache = <(ColorScheme?, Brightness, Color?, String?), ThemeData>{};

ThemeData _buildTheme(
  ColorScheme? dynamicScheme,
  Brightness brightness,
  Color? coverSeed,
  String? fontFamily,
) {
  final colorScheme = _withDistinctError(
    coverSeed != null
        ? ColorScheme.fromSeed(seedColor: coverSeed, brightness: brightness)
        : dynamicScheme?.harmonized() ??
              ColorScheme.fromSeed(
                seedColor: kanaruSeedColor,
                brightness: brightness,
              ),
  );

  final base = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    // The chosen font; bundled ones render the same on every machine (CJK
    // and emoji still fall back to the system fonts).
    fontFamily: fontFamily,
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

/// Below this CAM16-UCS distance an error color reads as the primary. Dark
/// tonal-spot schemes put both at tone 80, where reds hold only ~30 chroma,
/// so a red-family accent lands within ~4 of the error (the logo seed: 2.4).
/// Light pairs stay at 8.2 or more, since the light error keeps chroma 84.
const _minErrorDistance = 7.0;

/// Dark error tone used on a collision: low enough for the requested chroma
/// to show (84 is clamped to the sRGB gamut at this tone, about 61 to 66),
/// high enough for 4.5:1 on the dark surfaces and with the tone-20 onError.
const _collidingDarkErrorTone = 65.0;

/// Chroma of the Material 3 error palette.
const _errorChroma = 84.0;

/// In dark mode, swaps `error` for a lower-tone, high-chroma red of the same
/// hue when it sits too close to `primary`. Returns [scheme] itself otherwise.
ColorScheme _withDistinctError(ColorScheme scheme) {
  if (scheme.brightness != Brightness.dark) return scheme;
  final error = scheme.error.toARGB32();
  final distance = Cam16.fromInt(scheme.primary.toARGB32())
      .distance(Cam16.fromInt(error));
  if (distance >= _minErrorDistance) return scheme;
  final hue = Hct.fromInt(error).hue; // keeps the harmonized hue
  return scheme.copyWith(
    error: Color(Hct.from(hue, _errorChroma, _collidingDarkErrorTone).toInt()),
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
