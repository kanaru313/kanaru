import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/lyrics_action_runner.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:material_ui/material_ui.dart';

/// Now Playing, already open.
class _OpenNowPlaying extends NowPlayingOpen {
  @override
  bool build() => true;
}

void main() {
  testWidgets('the automatic notice link closes Now Playing and opens the '
      'lyrics settings without turning anything on', (tester) async {
    final container = ProviderContainer(
      overrides: [nowPlayingOpenProvider.overrideWith(_OpenNowPlaying.new)],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => TextButton(
            onPressed: () => LyricsActionRunner.snapshot(
              context,
              target: LyricsTarget.fromFields(
                uri: '/m/a.flac',
                title: 'Night Song',
                artist: 'Someone',
              ),
            ).enableAutomatic(),
            child: const Text('go'),
          ),
        ),
        GoRoute(
          path: settingsPlaybackRoute,
          builder: (_, _) => const Text('playback'),
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

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open lyrics settings'));
    await tester.pumpAndSettle();

    expect(container.read(nowPlayingOpenProvider), isFalse);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '$settingsPlaybackRoute?focus=lyrics',
    );
    expect(find.text('playback'), findsOneWidget);
    final prefs = container.read(settingsProvider).onlineLyrics;
    expect(prefs.autoFetch, isFalse);
    expect(prefs.autoConsent, isFalse);
  });
}
