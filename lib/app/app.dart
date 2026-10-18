import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'router.dart';
import 'theme.dart';

class KanaruApp extends ConsumerWidget {
  const KanaruApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Uses the platform accent color when available (GTK theme on Linux,
    // Material You on Android), otherwise falls back to Kanaru's seed color.
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp.router(
        title: 'Kanaru',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(lightDynamic, Brightness.light),
        darkTheme: buildTheme(darkDynamic, Brightness.dark),
        routerConfig: router,
      ),
    );
  }
}
