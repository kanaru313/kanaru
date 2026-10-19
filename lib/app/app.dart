import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../features/player/player_shortcuts.dart';
import '../l10n/l10n.dart';
import 'router.dart';
import 'theme.dart';

class KanaruApp extends ConsumerWidget {
  const KanaruApp({super.key, this.locale});

  /// Forces a UI language. `null` follows the system locale.
  final Locale? locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Uses the platform accent color when available (GTK theme on Linux,
    // Material You on Android), otherwise falls back to Kanaru's seed color.
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp.router(
        onGenerateTitle: (context) => context.l10n.appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(lightDynamic, Brightness.light),
        darkTheme: buildTheme(darkDynamic, Brightness.dark),
        locale: locale,
        // Material's own delegates come from material_ui, not
        // flutter_localizations, so its widgets find their translations.
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        // Above every route so playback keys work on any page and dialog.
        builder: (context, child) => PlayerShortcuts(child: child!),
      ),
    );
  }
}
