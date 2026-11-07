import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/lyrics_found_body.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_banner.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:kanaru/shared/translation_plugin_routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/fake_plugin_runner.dart';
import 'fake_translation_controller.dart';
import 'lyrics/fake_playing_lyrics_status.dart';

/// Now Playing, already open.
class _OpenNowPlaying extends NowPlayingOpen {
  @override
  bool build() => true;
}

void main() {
  late ProviderContainer container;
  late GoRouter router;

  /// Mounts [child] at `/` of a router, with Now Playing open.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        nowPlayingOpenProvider.overrideWith(_OpenNowPlaying.new),
        ...translatePluginOverrides(),
        ...overrides,
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            translation: TranslationPrefs(
              service: testTranslatePlugin,
              noticeAcknowledged: {testTranslatePlugin, testTranslatePlugin},
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
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
        GoRoute(
          path: settingsPlaybackRoute,
          builder: (_, _) => const Text('p'),
        ),
        GoRoute(path: settingsLibraryRoute, builder: (_, _) => const Text('l')),
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

  group('key banner', () {
    Widget banner(TranslationFailureKind kind, {bool keepsOld = false}) =>
        LyricsTranslationBanner(
          service: testTranslatePlugin,
          kind: kind,
          appLang: 'en',
          keepsOld: keepsOld,
        );

    for (final kind in [
      TranslationFailureKind.noKey,
      TranslationFailureKind.badKey,
    ]) {
      testWidgets('$kind opens the plugin page', (tester) async {
        await pump(tester, banner(kind));

        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();

        expect(container.read(nowPlayingOpenProvider), isFalse);
        expect(location(), translationPluginRoute(testTranslatePlugin.value));
      });
    }

    testWidgets('a failed retranslate offers retry and keeping the old', (
      tester,
    ) async {
      final fake = FakeTranslationController(
        TranslationOff(fakeTranslationInfo()),
      );
      await pump(
        tester,
        banner(TranslationFailureKind.server, keepsOld: true),
        overrides: [fakeTranslationOverride(fake)],
      );

      expect(find.textContaining('the old version stays'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.tap(find.text('Keep the old version'));
      await tester.pump();
      expect(fake.retranslateCalls, 1);
      expect(fake.retryCalls, 0);
      expect(fake.dismissFailureCalls, 1);
    });

    testWidgets('a retranslate failure over another service\'s row opens the '
        'selected service', (tester) async {
      final fake = FakeTranslationController(
        TranslationReady(
          // The song has its own service, which is not the default.
          fakeTranslationInfo(
            choice: fakeTranslationChoice(
              TranslationServiceId.tryParse('plugin-111111111111')!,
              scope: TranslationScope.song,
              defaultService: testTranslatePlugin,
            ),
          ),
          TranslationServiceId.tryParse('plugin-fedcba654321')!,
          'ja',
          const [],
          true,
          retranslateFailure: TranslationFailureKind.badKey,
        ),
      );
      await pump(
        tester,
        LyricsFoundBody(
          found: LyricsFound('file:///m/a.mp3', fakePlainLyrics()),
        ),
        overrides: [fakeTranslationOverride(fake)],
      );

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(location(), translationPluginRoute('plugin-111111111111'));
    });

    testWidgets('other failures have no such button', (tester) async {
      await pump(tester, banner(TranslationFailureKind.tooLong));

      expect(find.text('Open settings'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
