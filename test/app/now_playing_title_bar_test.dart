import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/shell/window/desktop_window.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../core/player/fake_audio_backend.dart';

/// Narrow window: Now Playing shows the tab header with its buttons.
const _narrow = Size(480, 800);

/// Wide window: Now Playing shows the header strip, empty without lyrics.
const _wide = Size(1280, 800);

void main() {
  late List<int> toggles;
  late List<int> drags;

  /// Opens Now Playing with a custom title bar. Window calls are counted in
  /// [toggles] and [drags], never sent to the window plugin.
  Future<void> pumpNowPlaying(
    WidgetTester tester, {
    Size size = _narrow,
  }) async {
    toggles = [];
    drags = [];
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        customTitleBarProvider.overrideWithValue(true),
        toggleMaximizeProvider.overrideWithValue(
          () async => toggles.add(toggles.length),
        ),
        startWindowDragProvider.overrideWithValue(
          () async => drags.add(drags.length),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KanaruApp(locale: Locale('en')),
      ),
    );
    await container.read(playerServiceProvider.notifier).openTracks([
      Track.fromPath('/music/First Song.flac'),
    ]);
    container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pumpAndSettle();
  }

  /// Two quick primary clicks at [at], with real time stamps (`tester.tap`
  /// stamps every event with zero, which hides the double click timing).
  Future<void> doubleClick(WidgetTester tester, Offset at) async {
    var now = Duration.zero;
    for (var i = 0; i < 2; i++) {
      final pointer = TestPointer(
        i + 1,
        PointerDeviceKind.mouse,
        null,
        kPrimaryButton,
      );
      await tester.sendEventToBinding(pointer.down(at, timeStamp: now));
      now += const Duration(milliseconds: 40);
      await tester.sendEventToBinding(pointer.up(timeStamp: now));
      now += const Duration(milliseconds: 100);
    }
    await tester.pump();
  }

  final queueButton = find.byIcon(Icons.queue_music_rounded);

  testWidgets('double clicking a header button leaves the window alone', (
    tester,
  ) async {
    await pumpNowPlaying(tester);

    await doubleClick(tester, tester.getCenter(queueButton));

    expect(toggles, isEmpty);
    expect(drags, isEmpty);
  });

  testWidgets('pressing and moving over a header button does not drag', (
    tester,
  ) async {
    await pumpNowPlaying(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(queueButton),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();
    await tester.pump();

    expect(drags, isEmpty);
  });

  testWidgets('double clicking empty header space maximizes once', (
    tester,
  ) async {
    await pumpNowPlaying(tester);

    // Right of the buttons, left of the window buttons.
    await doubleClick(tester, const Offset(140, 32));

    expect(toggles, hasLength(1));
  });

  testWidgets('dragging empty header space moves the window', (tester) async {
    await pumpNowPlaying(tester);

    final gesture = await tester.startGesture(
      const Offset(140, 32),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();

    expect(drags, hasLength(1));
  });

  testWidgets('double clicking the empty wide header maximizes once', (
    tester,
  ) async {
    await pumpNowPlaying(tester, size: _wide);

    await doubleClick(tester, const Offset(400, 32));

    expect(toggles, hasLength(1));
  });
}
