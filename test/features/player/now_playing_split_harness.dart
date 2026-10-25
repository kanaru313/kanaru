import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/features/player/now_playing/now_playing_track_column.dart';
import 'package:kanaru/features/player/track_artwork.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

const splitShortTrack = Track(
  uri: '/music/short.flac',
  title: 'Short',
  artist: 'Ann',
);
final splitLongTrack = Track(
  uri: '/music/long.flac',
  title: 'A very long title ' * 12,
  artist: 'Ann',
);

final splitColumn = find.byType(NowPlayingTrackColumn);
final splitCover = find.descendant(
  of: splitColumn,
  matching: find.byType(TrackArtwork),
);

/// Wide Now Playing on its own, with lyrics that can come and go.
class SplitHarness {
  late ProviderContainer container;
  late ValueNotifier<bool> hasLyrics;

  PlayerService get player => container.read(playerServiceProvider.notifier);

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    bool lyrics = true,
    List<Override> overrides = const [],
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    hasLyrics = ValueNotifier(lyrics);
    addTearDown(hasLyrics.dispose);
    await player.openTracks([splitShortTrack, splitLongTrack]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<bool>(
            valueListenable: hasLyrics,
            builder: (context, withLyrics, _) => NowPlayingScreen(
              lyrics: withLyrics
                  ? const SizedBox.expand(child: Center(child: Text('LYRICS')))
                  : null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}
