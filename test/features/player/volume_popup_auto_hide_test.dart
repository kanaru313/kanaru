import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_footer.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/volume_button.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

void main() {
  testWidgets('reports the volume popup opening and closing', (tester) async {
    final events = <bool>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(child: VolumeButton(onPopupChanged: events.add)),
        ),
      ),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(tester.getCenter(find.byType(VolumeButton)));
    await tester.pump();
    expect(events, [true]);

    // The pointer travelling button -> popup does not close it.
    await gesture.moveTo(tester.getCenter(find.byType(Slider)));
    await tester.pump(const Duration(seconds: 1));
    expect(events, [true]);

    await gesture.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 400));
    expect(events, [true, false]);
  });

  testWidgets('gives the pin back when removed with the popup open', (
    tester,
  ) async {
    final events = <bool>[];
    Widget app(Widget child) => ProviderScope(
      overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(child: child),
      ),
    );
    await tester.pumpWidget(app(VolumeButton(onPopupChanged: events.add)));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(VolumeButton)));
    await tester.pump();

    await tester.pumpWidget(app(const SizedBox()));

    expect(events, [true, false]);
  });

  /// Opens Now Playing with the pointer resting on the open volume popup.
  Future<(ProviderContainer, TestGesture)> restOnPopup(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final container = ProviderContainer(
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

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(300, 300));
    addTearDown(gesture.removePointer);
    await gesture.moveTo(
      tester.getCenter(
        find.descendant(
          of: find.byType(NowPlayingFooter),
          matching: find.byType(VolumeButton),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final popup = find.descendant(
      of: find.byType(Overlay),
      matching: find.text('100%'),
    );
    expect(popup, findsWidgets);
    await gesture.moveTo(tester.getCenter(popup.first));

    return (container, gesture);
  }

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

  testWidgets('Now Playing chrome stays while the pointer is on the popup', (
    tester,
  ) async {
    final (_, gesture) = await restOnPopup(tester);

    await tester.pump(const Duration(seconds: 4));
    expect(footerOpacity(tester), 1);

    // Off the popup and out of the footer: the popup closes, the chrome
    // fades after the usual stillness.
    await gesture.moveTo(const Offset(300, 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 4));
    expect(footerOpacity(tester), 0);
  });

  testWidgets('closing Now Playing with the popup open leaves no timer', (
    tester,
  ) async {
    final (container, _) = await restOnPopup(tester);

    container.read(nowPlayingOpenProvider.notifier).close();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
  });
}
