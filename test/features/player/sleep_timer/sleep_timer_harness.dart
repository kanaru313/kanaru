import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/playback_fade.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/sleep_timer.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/player_bar.dart';
import 'package:kanaru/features/player/sleep_timer/sleep_timer_button.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/fake_audio_backend.dart';
import '../../../core/player/manual_fade_clock.dart';

/// The whole app with two tracks queued and a manual clock for the timer.
class SleepTimerHarness {
  late ProviderContainer container;
  late ManualFadeClock time;

  SleepTimerState get state => container.read(sleepTimerProvider);
  SleepTimer get timer => container.read(sleepTimerProvider.notifier);

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    time = ManualFadeClock();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        playbackFadeClockProvider.overrideWithValue(time.clock),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KanaruApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
    await container.read(playerServiceProvider.notifier).openTracks([
      Track.fromPath('/music/a.mp3'),
      Track.fromPath('/music/b.mp3'),
    ]);
    await tester.pumpAndSettle();
  }

  /// The sleep timer button in the player bar.
  Finder get barButton => find.descendant(
    of: find.byType(PlayerBar),
    matching: find.byType(SleepTimerButton),
  );

  /// Opens the dialog from the player bar button.
  Future<void> open(WidgetTester tester) async {
    await tester.tap(
      find.descendant(of: barButton, matching: find.byType(IconButton)),
    );
    await tester.pumpAndSettle();
  }
}

final dialogFinder = find.byType(Dialog);

/// The dialog's card (the Dialog widget itself fills the window).
final dialogCard = find
    .descendant(of: dialogFinder, matching: find.byType(Material))
    .first;
