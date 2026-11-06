import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/playing_track_lyrics_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_service_needs_config_watch.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/lyrics_translation_modal.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:kanaru/shared/translation_plugin_routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics_translation/fake_plugin_runner.dart';
import '../../../../../core/player/fake_audio_backend.dart';
import '../../../fake_translation_controller.dart';

export '../../../../../core/lyrics_translation/fake_plugin_runner.dart';
export '../../../../../core/player/fake_audio_backend.dart';
export '../../../fake_translation_controller.dart';

const defaultModalTrack = Track(
  uri: '/m/song.flac',
  title: 'First Love',
  artist: 'Utada Hikaru',
);

const defaultSyncedLyrics = Lyrics(
  lines: [
    LyricLine(Duration.zero, '最後のキスは'),
    LyricLine(Duration(seconds: 5), 'タバコのflavorがした'),
  ],
  synced: true,
  source: LyricsSource.sidecar,
);

class _OpenNowPlaying extends NowPlayingOpen {
  @override
  bool build() => true;
}

class TranslationModalHarness {
  TranslationModalHarness({
    required this.container,
    required this.fake,
    required this.audio,
    required this.router,
    required this.visitedRoutes,
  });

  final ProviderContainer container;
  final FakeTranslationController fake;
  final FakeAudioBackend audio;
  final GoRouter router;
  final List<String> visitedRoutes;

  TranslationPrefs get prefs => container.read(settingsProvider).translation;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

Future<void> settleModal(WidgetTester tester) => settleTranslationModal(tester);

Future<TranslationModalHarness> pumpTranslationModal(
  WidgetTester tester, {
  LyricsTranslationState? state,
  TranslationPrefs? settings,
  bool followSettings = false,
  Size size = const Size(1280, 800),
  Locale locale = const Locale('en'),
  Track track = defaultModalTrack,
  Lyrics? lyrics = defaultSyncedLyrics,
  List<Override>? pluginOverrides,
  List<Override> overrides = const [],
  bool openModal = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final audio = FakeAudioBackend();
  final effectiveState = state ?? TranslationOff(fakeTranslationInfo());
  final fake = FakeTranslationController(
    effectiveState,
    followSettings: followSettings,
  );
  final effectiveSettings =
      settings ??
      TranslationPrefs(
        service: testTranslatePlugin,
        noticeAcknowledged: {testTranslatePlugin},
      );

  final container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(audio),
      nowPlayingOpenProvider.overrideWith(_OpenNowPlaying.new),
      playingTrackLyricsProvider.overrideWithValue(
        AsyncData(lyrics == null ? null : (uri: track.uri, lyrics: lyrics)),
      ),
      fakeTranslationOverride(fake),
      initialSettingsProvider.overrideWithValue(
        AppSettings(translation: effectiveSettings),
      ),
      ...(pluginOverrides ?? translatePluginOverrides()),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  await container.read(playerServiceProvider.notifier).openTracks([track]);
  container.read(translationServiceNeedsConfigWatchProvider);

  final visitedRoutes = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: FilledButton(
              onPressed: () => showLyricsTranslationModal(
                context,
                appLang: locale.languageCode,
              ),
              child: const Text('Open modal'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: settingsPlaybackRoute,
        builder: (_, s) {
          visitedRoutes.add(s.uri.toString());
          return const Scaffold(body: Text('Playback settings'));
        },
      ),
      GoRoute(
        path: translationPluginsRoute,
        builder: (_, s) {
          visitedRoutes.add(s.uri.toString());
          return const Scaffold(body: Text('Plugin store'));
        },
      ),
      GoRoute(
        path: translationPluginRoutePattern,
        builder: (_, s) {
          visitedRoutes.add(s.uri.toString());
          return const Scaffold(body: Text('Plugin page'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));

  if (openModal) {
    await tester.tap(find.text('Open modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  return TranslationModalHarness(
    container: container,
    fake: fake,
    audio: audio,
    router: router,
    visitedRoutes: visitedRoutes,
  );
}
