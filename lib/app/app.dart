import 'dart:math' as math;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/cover_colors/cover_palette.dart';
import '../core/cover_colors/playing_cover_palette_provider.dart';
import '../core/settings/applied_appearance_provider.dart';
import '../core/settings/settings_provider.dart';
import '../features/player/player_shortcuts.dart';
import '../l10n/l10n.dart';
import 'router.dart';
import 'theme.dart';

class KanaruApp extends ConsumerWidget {
  const KanaruApp({super.key, this.locale});

  /// Forces a UI language, ahead of the saved setting (used by tests).
  /// `null` uses the saved language, or the system locale if there is none.
  final Locale? locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Only what the app shell uses, so changing a library sort does not
    // rebuild MaterialApp; and settled, so quick clicks do not flash it.
    final (:theme, :languageCode) = ref.watch(appliedAppearanceProvider);
    // A saved code without a translation falls back to the system locale.
    final savedLocale =
        AppLocalizations.supportedLocales.any(
          (l) => l.languageCode == languageCode,
        )
        ? Locale(languageCode!)
        : null;
    // The playing cover's seed when "colors from the cover" is on and the
    // cover has a usable color; otherwise the system accent.
    final coverSeed = ref.watch(appCoverPaletteProvider.select((p) => p?.seed));
    // Read here, above the builder's override, so the setting is checked
    // along with the system's reduced motion.
    final animations = ref.watch(settingsProvider.select((s) => s.animations));
    final themeAnimationDuration =
        !animations || MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : coverThemeTransition;

    // Uses the platform accent color when available (GTK theme on Linux,
    // Material You on Android), otherwise falls back to Kanaru's seed color;
    // the playing cover's color comes first when there is one.
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp.router(
        onGenerateTitle: (context) => context.l10n.appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(lightDynamic, Brightness.light, coverSeed: coverSeed),
        darkTheme: buildTheme(
          darkDynamic,
          Brightness.dark,
          coverSeed: coverSeed,
        ),
        themeAnimationDuration: themeAnimationDuration,
        themeMode: switch (theme) {
          ThemePreference.system => ThemeMode.system,
          ThemePreference.light => ThemeMode.light,
          ThemePreference.dark => ThemeMode.dark,
        },
        locale: locale ?? savedLocale,
        // Material's own delegates come from material_ui, not
        // flutter_localizations, so its widgets find their translations.
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        // Above every route so playback keys, the motion setting and the
        // text size apply to every page, dialog and menu.
        builder: (context, child) =>
            _AppMediaOverrides(child: PlayerShortcuts(child: child!)),
      ),
    );
  }
}

/// Largest text scale the font size setting can reach, multiplied with the
/// system's. A system scale above it is kept as it is.
const maxAppTextScale = 2.0;

/// The text scaler for the system's [system] times the font size setting
/// [fontScale]. Enlarging stops at [maxAppTextScale], or at the system's own
/// scale when that is larger, so the setting never undoes a large system
/// size; shrinking multiplies as is. The system scale is linear on Linux.
TextScaler appTextScaler(TextScaler system, double fontScale) {
  if (fontScale == 1) return system;
  final systemScale = system.scale(100) / 100;
  final scale = math.min(
    systemScale * fontScale,
    math.max(systemScale, maxAppTextScale),
  );
  return TextScaler.linear(scale);
}

/// Applies the Animations switch (off forces reduced motion; on follows the
/// system) and the font size to everything below the app's builder. Its own
/// widget so that changing them does not rebuild [MaterialApp].
class _AppMediaOverrides extends ConsumerWidget {
  const _AppMediaOverrides({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (animations, fontScale) = ref.watch(
      settingsProvider.select((s) => (s.animations, s.display.fontScale)),
    );
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        disableAnimations: media.disableAnimations || !animations,
        textScaler: appTextScaler(media.textScaler, fontScale),
      ),
      child: child,
    );
  }
}
