import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/playback_fade.dart';
import 'package:kanaru/core/player/sleep_timer.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_auto_hide.dart';
import 'package:kanaru/features/player/now_playing/now_playing_header.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_title_bar.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import '../../core/player/manual_fade_clock.dart';

void main() {
  late ProviderContainer container;
  late FakeAudioBackend backend;
  late ManualFadeClock time;

  Future<void> pumpOpen(WidgetTester tester, {bool animations = false}) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: !animations);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
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
    ]);
    await tester.pumpAndSettle();
    container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pumpAndSettle();
  }

  /// Opacity of the header's [AutoHide].
  double headerOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.byType(NowPlayingHeader),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      )
      .opacity;

  bool headerIgnoresPointer(WidgetTester tester) => tester
      .widget<IgnorePointer>(
        find
            .ancestor(
              of: find.byType(NowPlayingHeader),
              matching: find.byType(IgnorePointer),
            )
            .first,
      )
      .ignoring;

  Future<TestGesture> mouse(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(900, 700));
    addTearDown(gesture.removePointer);
    await gesture.moveTo(const Offset(910, 700));
    await tester.pump();
    return gesture;
  }

  testWidgets('hides the header after three still seconds', (tester) async {
    await pumpOpen(tester);
    await mouse(tester);
    expect(headerOpacity(tester), 1);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(headerOpacity(tester), 1);

    await tester.pump(const Duration(milliseconds: 200));
    expect(headerOpacity(tester), 0);
    expect(headerIgnoresPointer(tester), isTrue);
    // Hidden, not gone: the layout does not move.
    expect(tester.getRect(find.byType(NowPlayingHeader)).top, 0);
  });

  /// The header alone under an [AutoHide], without the always-shown track
  /// column that ticks with the position.
  Future<(AutoHideController, ProviderContainer)> pumpHeaderOnly(
    WidgetTester tester, {
    bool animations = false,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: !animations);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    backend = FakeAudioBackend();
    time = ManualFadeClock();
    final harness = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        playbackFadeClockProvider.overrideWithValue(time.clock),
      ],
    );
    addTearDown(harness.dispose);
    final chrome = AutoHideController();
    addTearDown(chrome.dispose);
    final floating = ValueNotifier<bool>(false);
    addTearDown(floating.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: AutoHide(
                controller: chrome,
                child: NowPlayingHeader(
                  onClose: () {},
                  excludeFromDrag: noDragExclusion,
                  floatingOpen: floating,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await harness.read(playerServiceProvider.notifier).openTracks([
      Track.fromPath('/music/a.mp3'),
    ]);
    harness.read(sleepTimerProvider.notifier).startMinutes(10);
    await tester.pumpAndSettle();
    return (chrome, harness);
  }

  testWidgets('a hidden header schedules no frames while music plays', (
    tester,
  ) async {
    final (chrome, _) = await pumpHeaderOnly(tester, animations: true);
    backend.emitDuration.add(const Duration(minutes: 3));
    chrome.hideNow();
    // Past the fade-out.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    backend.emitPosition.add(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 64));
    backend.emitPosition.add(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 64));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('with reduced motion a hidden header schedules no frames', (
    tester,
  ) async {
    final (chrome, _) = await pumpHeaderOnly(tester);
    backend.emitDuration.add(const Duration(minutes: 3));
    chrome.hideNow();
    await tester.pump();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    backend.emitPosition.add(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 64));
    backend.emitPosition.add(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 64));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a hidden header holds the sleep label until it shows', (
    tester,
  ) async {
    final (chrome, _) = await pumpHeaderOnly(tester);
    expect(find.text('10:00'), findsOneWidget);
    chrome.hideNow();
    await tester.pump();
    await tester.pump();

    // The countdown moves on while nobody sees the label.
    await time.advance(const Duration(seconds: 30));
    await tester.pump();
    expect(find.text('10:00'), findsOneWidget);

    chrome.pin();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('9:30'), findsOneWidget);
    chrome.unpin();
    chrome.hideNow();
  });

  testWidgets('a header built while hidden schedules no frames', (
    tester,
  ) async {
    final controller = AutoHideController()..visible.value = false;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AutoHide(
          controller: controller,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the header fits larger text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpOpen(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('moving the pointer brings it back', (tester) async {
    await pumpOpen(tester);
    final gesture = await mouse(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(headerOpacity(tester), 0);

    await gesture.moveTo(const Offset(950, 700));
    await tester.pump();

    expect(headerOpacity(tester), 1);
    expect(headerIgnoresPointer(tester), isFalse);
    await tester.pump(const Duration(seconds: 4));
    expect(headerOpacity(tester), 0);
  });

  testWidgets('moving keeps it from hiding', (tester) async {
    await pumpOpen(tester);
    final gesture = await mouse(tester);

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
      await gesture.moveTo(Offset(920.0 + i * 10, 700));
      expect(headerOpacity(tester), 1);
    }
  });

  testWidgets('the pointer on the header keeps it', (tester) async {
    await pumpOpen(tester);
    final gesture = await mouse(tester);

    await gesture.moveTo(
      tester.getCenter(find.byType(NowPlayingHeader)) + const Offset(300, 0),
    );
    await tester.pump(const Duration(seconds: 10));
    expect(headerOpacity(tester), 1);

    // Leaving it starts the countdown.
    await gesture.moveTo(const Offset(900, 700));
    await tester.pump(const Duration(milliseconds: 3100));
    expect(headerOpacity(tester), 0);
  });

  testWidgets('a header that leaves under the pointer does not keep it', (
    tester,
  ) async {
    await pumpOpen(tester);
    final gesture = await mouse(tester);
    await gesture.moveTo(
      tester.getCenter(find.byType(NowPlayingHeader)) + const Offset(300, 0),
    );
    await tester.pump();

    // Narrow while the pointer rests on the header: the header goes away
    // without the pointer ever leaving it.
    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingHeader), findsNothing);
    await gesture.moveTo(const Offset(900, 700));
    await tester.pump();

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pump();
    await gesture.moveTo(const Offset(910, 700));
    await tester.pump(const Duration(milliseconds: 3100));
    expect(headerOpacity(tester), 0);
  });

  testWidgets('hides at once when the pointer leaves the window', (
    tester,
  ) async {
    await pumpOpen(tester);
    final gesture = await mouse(tester);

    await gesture.removePointer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(headerOpacity(tester), 0);
  });

  testWidgets('a key press brings it back', (tester) async {
    await pumpOpen(tester);
    await mouse(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(headerOpacity(tester), 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(headerOpacity(tester), 1);
  });

  testWidgets('the cursor hides with the header', (tester) async {
    await pumpOpen(tester);
    await mouse(tester);
    expect(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
      isNot(SystemMouseCursors.none),
    );

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.none,
    );
  });
}
