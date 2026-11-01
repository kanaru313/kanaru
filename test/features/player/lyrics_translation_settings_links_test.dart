import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_banner.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_button.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_translation_controller.dart';

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
        ...overrides,
        initialSettingsProvider.overrideWithValue(
          const AppSettings(
            translation: TranslationPrefs(
              noticeAcknowledged: {LyricsTranslationService.google},
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

  testWidgets('the translation menu ends with a link to its settings', (
    tester,
  ) async {
    final fake = FakeTranslationController(
      TranslationReady(
        fakeTranslationInfo(),
        LyricsTranslationService.google,
        'ja',
        const [],
        false,
      ),
    );
    await pump(
      tester,
      const LyricsTranslationButton(),
      overrides: [fakeTranslationOverride(fake)],
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(nowPlayingOpenProvider), isTrue);
    await tester.tap(find.text('Translation settings'));
    await tester.pumpAndSettle();

    expect(container.read(nowPlayingOpenProvider), isFalse);
    expect(location(), '$settingsPlaybackRoute?focus=translation');
  });

  group('key banner', () {
    Widget banner(TranslationFailureKind kind) => LyricsTranslationBanner(
      state: TranslationFailed(
        fakeTranslationInfo(),
        LyricsTranslationService.google,
        kind,
      ),
      appLang: 'en',
    );

    for (final kind in [
      TranslationFailureKind.noKey,
      TranslationFailureKind.badKey,
    ]) {
      testWidgets('$kind opens the translation settings', (tester) async {
        await pump(tester, banner(kind));

        await tester.tap(find.text("Open the service's settings"));
        await tester.pumpAndSettle();

        expect(container.read(nowPlayingOpenProvider), isFalse);
        expect(location(), '$settingsPlaybackRoute?focus=translation');
      });
    }

    testWidgets('other failures have no such button', (tester) async {
      await pump(tester, banner(TranslationFailureKind.tooLong));

      expect(find.text("Open the service's settings"), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
