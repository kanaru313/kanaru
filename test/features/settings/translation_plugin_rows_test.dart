import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/translation_plugin_rows.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/translation_plugin_routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/fake_plugin_runner.dart';

const _id = 'plugin-abc123def456';

void main() {
  late GoRouter router;

  Future<void> pump(WidgetTester tester) async {
    final records = [translateRecord(_id, name: 'Gemini')];
    final container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(const AppSettings()),
        lyricsPluginRecordsProvider.overrideWithValue(records),
        translatePluginRecordsProvider.overrideWithValue(
          AsyncValue.data(records),
        ),
      ],
    );
    addTearDown(container.dispose);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: TranslationPluginRows()),
        ),
        GoRoute(
          path: translationPluginRoutePattern,
          builder: (_, _) => const Text('page'),
        ),
        GoRoute(
          path: translationPluginsRoute,
          builder: (_, _) => const Text('store'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
  }

  String location() =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('a plugin row opens the plugin page', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Gemini'));
    await tester.pumpAndSettle();

    expect(location(), translationPluginRoute(_id));
  });

  testWidgets('the store row opens the store on translation services', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Get translation services'));
    await tester.pumpAndSettle();

    expect(location(), translationPluginsRoute);
  });
}
