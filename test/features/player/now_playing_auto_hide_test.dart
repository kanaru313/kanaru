import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_footer.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpOpen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
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

  /// Opacity of the footer's [AutoHide].
  double footerOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.byType(NowPlayingFooter),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      )
      .opacity;

  bool footerIgnoresPointer(WidgetTester tester) => tester
      .widget<IgnorePointer>(
        find
            .ancestor(
              of: find.byType(NowPlayingFooter),
              matching: find.byType(IgnorePointer),
            )
            .first,
      )
      .ignoring;

  Future<TestGesture> mouse(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(300, 300));
    addTearDown(gesture.removePointer);
    await gesture.moveTo(const Offset(310, 300));
    await tester.pump();
    return gesture;
  }

  testWidgets('hides the footer after three still seconds', (tester) async {
    await pumpOpen(tester);
    await mouse(tester);
    expect(footerOpacity(tester), 1);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(footerOpacity(tester), 1);

    await tester.pump(const Duration(milliseconds: 200));
    expect(footerOpacity(tester), 0);
    expect(footerIgnoresPointer(tester), isTrue);
    // Hidden, not gone: the layout does not move.
    expect(tester.getRect(find.byType(NowPlayingFooter)).bottom, 800);
  });

  testWidgets('moving the pointer brings it back', (tester) async {
    await pumpOpen(tester);
    final gesture = await mouse(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(footerOpacity(tester), 0);

    await gesture.moveTo(const Offset(400, 300));
    await tester.pump();

    expect(footerOpacity(tester), 1);
    expect(footerIgnoresPointer(tester), isFalse);
    await tester.pump(const Duration(seconds: 4));
    expect(footerOpacity(tester), 0);
  });

  testWidgets('moving keeps it from hiding', (tester) async {
    await pumpOpen(tester);
    final gesture = await mouse(tester);

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
      await gesture.moveTo(Offset(320.0 + i * 10, 300));
      expect(footerOpacity(tester), 1);
    }
  });

  testWidgets('the pointer on the footer keeps it', (tester) async {
    await pumpOpen(tester);
    final gesture = await mouse(tester);

    await gesture.moveTo(
      tester.getCenter(find.byType(NowPlayingFooter)) + const Offset(300, 0),
    );
    await tester.pump(const Duration(seconds: 10));
    expect(footerOpacity(tester), 1);

    // Leaving it starts the countdown.
    await gesture.moveTo(const Offset(300, 300));
    await tester.pump(const Duration(milliseconds: 3100));
    expect(footerOpacity(tester), 0);
  });

  testWidgets('a footer that leaves under the pointer does not keep it', (
    tester,
  ) async {
    await pumpOpen(tester);
    final gesture = await mouse(tester);
    await gesture.moveTo(
      tester.getCenter(find.byType(NowPlayingFooter)) + const Offset(300, 0),
    );
    await tester.pump();

    // Narrow while the pointer rests on the footer: the footer goes away
    // without the pointer ever leaving it.
    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingFooter), findsNothing);
    await gesture.moveTo(const Offset(300, 300));
    await tester.pump();

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pump();
    await gesture.moveTo(const Offset(310, 300));
    await tester.pump(const Duration(milliseconds: 3100));
    expect(footerOpacity(tester), 0);
  });

  testWidgets('hides at once when the pointer leaves the window', (
    tester,
  ) async {
    await pumpOpen(tester);
    final gesture = await mouse(tester);

    await gesture.removePointer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(footerOpacity(tester), 0);
  });

  testWidgets('a key press brings it back', (tester) async {
    await pumpOpen(tester);
    await mouse(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(footerOpacity(tester), 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(footerOpacity(tester), 1);
  });

  testWidgets('the cursor hides with the footer', (tester) async {
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
