import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_controller.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_banner.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/translation_plugin_routes.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_translation_controller.dart';

const _id = 'plugin-abc123def456';

class _OpenNowPlaying extends NowPlayingOpen {
  @override
  bool build() => true;
}

void main() {
  final plugin = TranslationServiceId.tryParse(_id)!;
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester,
    TranslationServiceId service,
    TranslationFailureKind kind, {
    Set<TranslationServiceId> acknowledged = const {},
  }) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        nowPlayingOpenProvider.overrideWith(_OpenNowPlaying.new),
        // A new instance per build: the provider rebuilds when the settings
        // change, and a notifier cannot be reused.
        lyricsTranslationProvider.overrideWith2(
          (_) =>
              FakeTranslationController(TranslationOff(fakeTranslationInfo())),
        ),
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            translation: TranslationPrefs(
              show: true,
              service: service,
              noticeAcknowledged: {...acknowledged, service},
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: LyricsTranslationBanner(
              service: service,
              kind: kind,
              appLang: 'en',
            ),
          ),
        ),
        GoRoute(
          path: translationPluginRoutePattern,
          builder: (_, _) => const Text('plugin page'),
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
    await tester.pump(const Duration(milliseconds: 50));
  }

  String location() =>
      router.routerDelegate.currentConfiguration.uri.toString();

  for (final kind in [
    TranslationFailureKind.noKey,
    TranslationFailureKind.badKey,
    TranslationFailureKind.keyStoreLocked,
  ]) {
    testWidgets('plugin $kind: Open settings opens the plugin page', (
      tester,
    ) async {
      await pump(tester, plugin, kind);

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(container.read(nowPlayingOpenProvider), isFalse);
      expect(location(), translationPluginRoute(_id));
    });
  }

  testWidgets('plugin needsConfig: opens the plugin page, no Retry', (
    tester,
  ) async {
    await pump(tester, plugin, TranslationFailureKind.needsConfig);

    expect(
      find.text(
        'This translation plugin needs configuration before it can run.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.text('Open config'));
    await tester.pumpAndSettle();

    expect(container.read(nowPlayingOpenProvider), isFalse);
    expect(location(), translationPluginRoute(_id));
  });

  testWidgets('quota, rate limit, and network failures offer Retry only', (
    tester,
  ) async {
    for (final kind in [
      TranslationFailureKind.quotaExceeded,
      TranslationFailureKind.rateLimited,
      TranslationFailureKind.network,
      TranslationFailureKind.server,
    ]) {
      await pump(tester, plugin, kind);

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Open settings'), findsNothing);
      expect(find.text('Open config'), findsNothing);
    }
  });
}
