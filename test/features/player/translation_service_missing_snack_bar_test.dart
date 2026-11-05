import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/features/player/lyrics/translation/translation_service_missing_snack_bar.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:kanaru/shared/translation_plugin_routes.dart';
import 'package:material_ui/material_ui.dart';

class _OpenNowPlaying extends NowPlayingOpen {
  @override
  bool build() => true;
}

void main() {
  Future<(ProviderContainer, List<String>)> pumpHarness(
    WidgetTester tester, {
    required bool hasPlugins,
  }) async {
    final visited = <String>[];
    final container = ProviderContainer(
      overrides: [nowPlayingOpenProvider.overrideWith(_OpenNowPlaying.new)],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/player',
      routes: [
        GoRoute(
          path: '/player',
          builder: (_, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => FilledButton(
                onPressed: () => showTranslationServiceMissingSnackBar(
                  context,
                  ref,
                  hasPlugins: hasPlugins,
                ),
                child: const Text('Trigger'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: translationPluginsRoute,
          builder: (_, state) {
            visited.add(state.uri.toString());
            return const Scaffold(body: Text('Plugin store'));
          },
        ),
        GoRoute(
          path: settingsPlaybackRoute,
          builder: (_, state) {
            visited.add(state.uri.toString());
            return const Scaffold(body: Text('Playback settings'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container, visited);
  }

  testWidgets(
    'without plugins: shows no-plugin snackbar and opens the plugin store',
    (tester) async {
      final (container, visited) = await pumpHarness(
        tester,
        hasPlugins: false,
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(
        find.text('Install a translation plugin to translate lyrics'),
        findsOneWidget,
      );
      expect(find.text('Open plugin store'), findsOneWidget);

      await tester.tap(find.text('Open plugin store'));
      await tester.pumpAndSettle();

      expect(container.read(nowPlayingOpenProvider), isFalse);
      expect(visited, [translationPluginsRoute]);
    },
  );

  testWidgets(
    'with plugins: shows choose-service snackbar and opens translation settings',
    (tester) async {
      final (container, visited) = await pumpHarness(
        tester,
        hasPlugins: true,
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a translation service first'), findsOneWidget);
      expect(find.text('Choose service'), findsOneWidget);

      await tester.tap(find.text('Choose service'));
      await tester.pumpAndSettle();

      expect(container.read(nowPlayingOpenProvider), isFalse);
      expect(visited, [
        settingsFocusLocation(SettingsAnchor.playbackTranslation),
      ]);
    },
  );
}
