import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_auto_hide.dart';
import 'package:kanaru/features/player/seek_bar.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import 'now_playing_split_harness.dart' show splitLongTrack, splitShortTrack;

export 'now_playing_split_harness.dart' show splitLongTrack, splitShortTrack;

/// A Now Playing body on its own, in a window of the given size, with a
/// queue of a short and a long titled song and a controller for its chrome.
class BodyHarness {
  late ProviderContainer container;
  late FakeAudioBackend backend;
  late AutoHideController chrome;

  PlayerService get player => container.read(playerServiceProvider.notifier);

  Future<void> pump(
    WidgetTester tester, {
    required Widget Function(AutoHideController chrome) body,
    Size size = const Size(1280, 800),
    double textScale = 1,
    bool reduceMotion = true,
    List<Override> overrides = const [],
    List<Track>? tracks,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduceMotion);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    chrome = AutoHideController();
    addTearDown(chrome.dispose);
    await player.openTracks(tracks ?? [splitShortTrack, splitLongTrack]);
    backend.emitDuration.add(const Duration(minutes: 3));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: body(chrome)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Hides the chrome and lets the fade-out finish.
  Future<void> hide(WidgetTester tester) async {
    chrome.hideNow();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Shows the chrome and lets the fade-in finish. It stays shown: a pin
  /// leaves no hide timer pending when the test ends.
  Future<void> show(WidgetTester tester) async {
    chrome.pin();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// While hidden, position ticks schedule no frame and leave the elapsed
  /// label at its old value; shown again, the label catches up.
  Future<void> expectMutedWhileHidden(WidgetTester tester) async {
    final label = find.descendant(
      of: find.byType(SeekElapsedLabel),
      matching: find.byType(Text),
    );
    final before = tester.widget<Text>(label).data;
    backend.emitPosition.add(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 64));
    backend.emitPosition.add(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 64));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.widget<Text>(label).data, before);

    await show(tester);
    await tester.pump();
    expect(tester.widget<Text>(label).data, '0:05');
  }

  /// A mouse that rests on [target] keeps the chrome shown past the delay.
  Future<void> expectPointerPins(WidgetTester tester, Finder target) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    chrome.poke();
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(chrome.visible.value, isTrue);

    await gesture.moveTo(const Offset(1, 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(chrome.visible.value, isFalse);
  }
}
