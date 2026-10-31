import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/shell/window/desktop_window.dart';
import 'package:kanaru/app/shell/window/window_buttons.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/lyrics/source/lyrics_source_button.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_tab_dot.dart';
import 'package:material_ui/material_ui.dart';

import '../core/player/fake_audio_backend.dart';

/// Smallest window the desktop shell allows (`desktop_window.dart`).
const _minWindow = Size(480, 720);

/// Least empty strip between the left button group and the tab dots that
/// still leaves room to grab the window.
const _minDragStrip = 16.0;

/// Narrow Now Playing header at the minimum window width, on the geometry of
/// the real Linux app: the platform is pinned to Linux so the theme resolves
/// compact density (44 px icon buttons, left group ending at x=184) instead of
/// the test default (Android, 48 px buttons).
void main() {
  late List<int> toggles;
  late List<int> drags;

  /// A test that runs with the platform pinned to Linux. The override is
  /// reset in `finally`, before Flutter checks it at the end of the test.
  void linuxTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(description, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  /// Opens Now Playing at the minimum window size. Window calls are counted
  /// in [toggles] and [drags], never sent to the window plugin.
  Future<void> pumpNarrow(
    WidgetTester tester, {
    required bool customTitleBar,
  }) async {
    toggles = [];
    drags = [];
    tester.view.physicalSize = _minWindow;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        customTitleBarProvider.overrideWithValue(customTitleBar),
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

  Future<void> pressAndMove(WidgetTester tester, Offset at) async {
    final gesture = await tester.startGesture(
      at,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();
    await tester.pump();
  }

  final dots = find.byType(NowPlayingTabDot);

  Rect sourceRect(WidgetTester tester) =>
      tester.getRect(find.byType(LyricsSourceButton));

  Rect firstDotRect(WidgetTester tester) => tester.getRect(dots.first);

  /// Middle of the strip between the left button group and the first dot.
  Offset stripCenter(WidgetTester tester) {
    final source = sourceRect(tester);
    return Offset(
      (source.right + firstDotRect(tester).left) / 2,
      source.center.dy,
    );
  }

  /// Dot [index]'s `selected` flag.
  bool isSelected(WidgetTester tester, int index) =>
      tester.widget<NowPlayingTabDot>(dots.at(index)).selected;

  void expectDragStripFits(WidgetTester tester, {required bool customBar}) {
    final source = sourceRect(tester);
    final first = firstDotRect(tester);
    final last = tester.getRect(dots.last);
    // The header ends where the window buttons start, else at the window edge.
    final buttons = find.byType(WindowButtons);
    final headerEnd = customBar
        ? tester.getRect(buttons).left
        : _minWindow.width;
    expect(buttons, customBar ? findsOneWidget : findsNothing);
    expect(dots, findsNWidgets(3));
    expect(
      first.left - source.right,
      greaterThanOrEqualTo(_minDragStrip),
      reason: 'strip between the source button and the first dot',
    );
    expect(first.left, greaterThan(source.right), reason: 'dots overlap');
    expect(
      last.right,
      lessThanOrEqualTo(headerEnd - _minDragStrip),
      reason: 'strip between the last dot and the header end',
    );
  }

  /// Taps the lyrics dot (last) and expects it to become the selected tab.
  Future<void> expectDotTapSwitchesTab(WidgetTester tester) async {
    expect(isSelected(tester, 1), isTrue, reason: 'track tab starts selected');
    expect(isSelected(tester, 2), isFalse);
    await tester.tap(dots.at(2));
    await tester.pumpAndSettle();
    expect(isSelected(tester, 2), isTrue);
    expect(isSelected(tester, 1), isFalse);
  }

  group('custom title bar', () {
    linuxTest('keeps a drag strip between the left buttons and the dots', (
      tester,
    ) async {
      await pumpNarrow(tester, customTitleBar: true);

      expectDragStripFits(tester, customBar: true);
    });

    linuxTest('double clicking the strip before the dots maximizes once', (
      tester,
    ) async {
      await pumpNarrow(tester, customTitleBar: true);

      await doubleClick(tester, stripCenter(tester));

      expect(toggles, hasLength(1));
    });

    linuxTest('pressing and moving in the strip before the dots drags once', (
      tester,
    ) async {
      await pumpNarrow(tester, customTitleBar: true);

      await pressAndMove(tester, stripCenter(tester));

      expect(drags, hasLength(1));
    });

    linuxTest('double clicking a tab dot leaves the window alone', (
      tester,
    ) async {
      await pumpNarrow(tester, customTitleBar: true);

      await doubleClick(tester, tester.getCenter(dots.first));

      expect(toggles, isEmpty);
      expect(drags, isEmpty);
    });

    linuxTest('pressing and moving over a tab dot does not drag', (
      tester,
    ) async {
      await pumpNarrow(tester, customTitleBar: true);

      await pressAndMove(tester, tester.getCenter(dots.first));

      expect(drags, isEmpty);
      expect(toggles, isEmpty);
    });

    linuxTest('tapping a tab dot switches the tab', (tester) async {
      await pumpNarrow(tester, customTitleBar: true);

      await expectDotTapSwitchesTab(tester);
      expect(drags, isEmpty);
      expect(toggles, isEmpty);
    });
  });

  group('system title bar', () {
    linuxTest('keeps a strip between the left buttons and the dots', (
      tester,
    ) async {
      await pumpNarrow(tester, customTitleBar: false);

      expectDragStripFits(tester, customBar: false);
    });

    linuxTest('tapping a tab dot switches the tab', (tester) async {
      await pumpNarrow(tester, customTitleBar: false);

      await expectDotTapSwitchesTab(tester);
    });
  });
}
