import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/player_bar.dart';
import 'package:kanaru/features/player/seek_bar.dart';
import 'package:kanaru/features/player/seek_gesture_area.dart';
import 'package:kanaru/features/player/seek_strip.dart';
import 'package:kanaru/features/player/volume_button.dart';
import 'package:kanaru/features/player/wavy_track_painter.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

final songs = [
  Track.fromPath('/music/First Song.flac'),
  Track.fromPath('/music/Second Song.mp3'),
];

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  PlayerService player() => container.read(playerServiceProvider.notifier);

  /// Animations are off unless asked for: the seek bar's wave never
  /// settles while music plays.
  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    bool animations = false,
  }) async {
    tester.view.physicalSize = size;
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
  }

  Future<void> openSongs(WidgetTester tester) async {
    await player().openTracks(songs);
    backend.calls.clear();
    await tester.pumpAndSettle();
  }

  testWidgets('hides the bar while nothing is queued', (tester) async {
    await pumpApp(tester);
    expect(find.byType(PlayerBar), findsNothing);

    await openSongs(tester);
    expect(find.byType(PlayerBar), findsOneWidget);
  });

  testWidgets('shows the current track and controls playback', (tester) async {
    await pumpApp(tester);
    await openSongs(tester);

    expect(find.text('First Song'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pumpAndSettle();
    expect(backend.calls, ['pause']);
    expect(find.byTooltip('Play'), findsOneWidget);

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(backend.calls.last, 'open(Second Song, next: null)');
    expect(find.text('Second Song'), findsOneWidget);
  });

  testWidgets('shows the times around the seek bar and repeat state', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSongs(tester);
    backend.emitDuration.add(const Duration(minutes: 3, seconds: 5));
    backend.emitPosition.add(const Duration(seconds: 42));
    await tester.pump();

    final bar = tester.getRect(find.byType(SeekGestureArea));
    expect(tester.getCenter(find.text('0:42')).dx, lessThan(bar.left));
    expect(tester.getCenter(find.text('3:05')).dx, greaterThan(bar.right));

    await tester.tap(find.byTooltip('Repeat off'));
    await tester.pump();
    await tester.tap(find.byTooltip('Repeat all'));
    await tester.pump();
    expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);
    expect(backend.calls.where((c) => c.startsWith('setRepeat')), [
      'setRepeat(all)',
      'setRepeat(one)',
    ]);
  });

  group('keyboard', () {
    testWidgets('Space plays/pauses with nothing focused', (tester) async {
      await pumpApp(tester);
      await openSongs(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(backend.calls, ['pause']);
    });

    testWidgets(
      'Space on a focused button plays/pauses instead of pressing it',
      (tester) async {
        await pumpApp(tester);
        await openSongs(tester);
        Focus.of(tester.element(find.byIcon(Icons.skip_next_rounded)))
            .requestFocus();
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(backend.calls, ['pause']);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(backend.calls, ['pause', 'open(Second Song, next: null)']);
      },
    );

    testWidgets('Space in the search field types instead', (tester) async {
      await pumpApp(tester);
      await openSongs(tester);
      await tester.tap(find.byType(SearchBar));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(backend.calls, isEmpty);
    });

    testWidgets('keys pass through while the queue is empty', (tester) async {
      await pumpApp(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(backend.calls, isEmpty);
    });

    testWidgets('arrows seek by 5 seconds', (tester) async {
      await pumpApp(tester);
      await openSongs(tester);
      backend.emitDuration.add(const Duration(minutes: 3));
      backend.emitPosition.add(const Duration(seconds: 20));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(backend.calls, [
        'seek(${const Duration(seconds: 25)})',
        'seek(${const Duration(seconds: 20)})',
      ]);
    });

    testWidgets('Ctrl+S shuffles and Ctrl+R cycles repeat', (tester) async {
      await pumpApp(tester);
      await openSongs(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final queue = container.read(playerServiceProvider).queue;
      expect(queue.shuffled, isTrue);
      expect(queue.repeat.name, 'all');
    });
  });

  testWidgets('a drag that outlives its track does not seek the next one', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSongs(tester);
    backend.emitDuration.add(const Duration(seconds: 100));
    await tester.pump();

    final strip = tester.getRect(find.byType(SeekGestureArea));
    final drag = await tester.startGesture(
      Offset(strip.left + strip.width / 4, strip.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await drag.moveBy(const Offset(40, 0));
    await tester.pump();
    // The engine moves on mid-drag; the new duration is not known yet.
    backend.advance();
    await tester.pump();
    await drag.moveBy(const Offset(40, 0));
    await drag.up();
    await tester.pumpAndSettle();

    expect(backend.calls.where((c) => c.startsWith('seek')), isEmpty);

    // The strip is not stuck: the next drag on the new track seeks.
    backend.emitDuration.add(const Duration(seconds: 200));
    await tester.pump();
    final again = await tester.startGesture(
      Offset(strip.left + strip.width / 4, strip.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await again.moveBy(const Offset(40, 0));
    await again.up();
    await tester.pumpAndSettle();
    expect(backend.calls.where((c) => c.startsWith('seek')), hasLength(1));
  });

  testWidgets('narrow windows keep one row with play/pause and next', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(480, 640));
    await openSongs(tester);

    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.byTooltip('Next'), findsOneWidget);
    for (final tooltip in ['Shuffle', 'Previous', 'Repeat off', 'Mute']) {
      expect(find.byTooltip(tooltip), findsNothing);
    }
    expect(find.byType(VolumeButton), findsNothing);
    expect(
      tester.getCenter(find.byTooltip('Pause')).dy,
      moreOrLessEquals(tester.getCenter(find.text('First Song')).dy),
    );

    // What left the bar stays on the keyboard.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(container.read(playerServiceProvider).queue.shuffled, isTrue);
  });

  testWidgets('a broken track shows a snack bar', (tester) async {
    await pumpApp(tester);
    await openSongs(tester);

    backend.fail(container.read(playerServiceProvider).queue.current!);
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't play First Song"), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  for (final (name, size) in [
    ('narrow', const Size(360, 640)),
    ('compact', const Size(480, 640)),
    ('medium', const Size(720, 640)),
  ]) {
    testWidgets('lays out without overflow when $name', (tester) async {
      await pumpApp(tester, size: size);
      await openSongs(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(PlayerBar)).width, size.width);
    });
  }

  for (final width in [480.0, 560.0, 640.0, 720.0]) {
    testWidgets('leaves the title room at width $width', (tester) async {
      await pumpApp(tester, size: Size(width, 640));
      await openSongs(tester);
      expect(
        tester.getSize(find.text('First Song')).width,
        greaterThanOrEqualTo(120),
      );
    });
  }

  testWidgets('greys out previous and next at the ends of the queue', (
    tester,
  ) async {
    IconButton button(IconData icon) => tester.widget<IconButton>(
      find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton)),
    );
    await pumpApp(tester);
    await openSongs(tester);
    expect(button(Icons.skip_previous_rounded).onPressed, isNull);
    expect(button(Icons.skip_next_rounded).onPressed, isNotNull);

    await player().next();
    await tester.pump();
    expect(button(Icons.skip_previous_rounded).onPressed, isNotNull);
    expect(button(Icons.skip_next_rounded).onPressed, isNull);

    await player().cycleRepeat();
    await tester.pump();
    expect(button(Icons.skip_next_rounded).onPressed, isNotNull);
  });

  testWidgets('narrow windows seek on a thin strip on the top edge', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(480, 640));
    await openSongs(tester);
    expect(find.byType(SeekStrip), findsOneWidget);
    expect(find.byType(SeekBar), findsNothing);
    expect(
      tester.getRect(find.byType(SeekStrip)).top,
      tester.getRect(find.byType(PlayerBar)).top,
    );
  });

  testWidgets('wide windows seek under the controls', (tester) async {
    await pumpApp(tester);
    await openSongs(tester);
    expect(find.byType(SeekStrip), findsNothing);
    expect(
      tester.getCenter(find.byType(SeekBar)).dy,
      greaterThan(tester.getCenter(find.byTooltip('Pause')).dy),
    );
    expect(
      tester.getCenter(find.byType(SeekBar)).dx,
      moreOrLessEquals(tester.getCenter(find.byTooltip('Pause')).dx),
    );
  });

  group('wave', () {
    WavyTrackPainter painter(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(SeekBar),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as WavyTrackPainter;

    testWidgets('travels while playing and lies flat when paused', (
      tester,
    ) async {
      await pumpApp(tester, animations: true);
      await player().openTracks(songs);
      backend.emitDuration.add(const Duration(minutes: 3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(painter(tester).amplitude.value, 1);
      final phase = painter(tester).phase.value;
      await tester.pump(const Duration(milliseconds: 100));
      expect(painter(tester).phase.value, isNot(phase));

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(painter(tester).amplitude.value, 0);
      // Once the button's ripple is gone too, nothing draws any more.
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('stands still while the window is not focused', (tester) async {
      await pumpApp(tester, animations: true);
      await player().openTracks(songs);
      backend.emitDuration.add(const Duration(minutes: 3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(painter(tester).amplitude.value, 1);

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(seconds: 2));
        expect(painter(tester).amplitude.value, 0, reason: '$state');
        expect(tester.binding.hasScheduledFrame, isFalse, reason: '$state');
      }

      // Lifecycle states come back one step at a time.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(painter(tester).amplitude.value, 1);
      final phase = painter(tester).phase.value;
      await tester.pump(const Duration(milliseconds: 100));
      expect(painter(tester).phase.value, isNot(phase));
    });

    testWidgets('lies flat with animations turned off', (tester) async {
      await pumpApp(tester);
      await openSongs(tester);
      backend.emitDuration.add(const Duration(minutes: 3));
      await tester.pump();

      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(painter(tester).amplitude.value, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('seek bar height', () {
    Future<double> height(WidgetTester tester, double scale) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester);
      await openSongs(tester);
      return tester.getSize(find.byType(SeekBar)).height;
    }

    testWidgets('stays as high as the track in small text', (tester) async {
      expect(await height(tester, 0.8), 24);
    });

    testWidgets('keeps the track height at normal text', (tester) async {
      expect(await height(tester, 1), 24);
    });

    for (final scale in [1.5, 2.0]) {
      testWidgets('grows with the time labels at text scale $scale', (
        tester,
      ) async {
        final h = await height(tester, scale);

        expect(h, greaterThanOrEqualTo(12 * 1.33 * scale));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('position ticks', () {
    /// Counts how often each render object is painted into
    /// while [body] runs.
    Future<Map<RenderObject, int>> paints(
      WidgetTester tester,
      Future<void> Function() body,
    ) async {
      final counts = <RenderObject, int>{};
      debugOnProfilePaint = (object) =>
          counts.update(object, (n) => n + 1, ifAbsent: () => 1);
      try {
        await body();
      } finally {
        debugOnProfilePaint = null;
      }
      return counts;
    }

    RenderObject text(WidgetTester tester, String data) =>
        tester.renderObject(find.text(data).first);

    Future<void> tick(WidgetTester tester, int seconds) async {
      backend.emitPosition.add(Duration(seconds: seconds));
      await tester.pump();
    }

    testWidgets('repaint the seek bar but not the rest of the bar', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSongs(tester);
      backend.emitDuration.add(const Duration(minutes: 3));
      await tick(tester, 1);

      final counts = await paints(tester, () => tick(tester, 2));

      expect(counts[text(tester, '0:02')], 1);
      expect(counts[text(tester, 'First Song')], isNull);
      // The scaffold around the bar is not painted again.
      expect(counts[tester.renderObject(find.byType(PlayerBar))], isNull);
    });

    testWidgets('repaint the seek strip but not the rest of the bar', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(480, 640));
      await openSongs(tester);
      backend.emitDuration.add(const Duration(minutes: 3));
      await tick(tester, 1);

      final counts = await paints(tester, () => tick(tester, 2));
      final strip = find.descendant(
        of: find.byType(SeekStrip),
        matching: find.byType(Stack),
      );
      expect(counts[tester.renderObject(strip.first)], 1);
      expect(counts[text(tester, 'First Song')], isNull);
      // The scaffold around the bar is not painted again.
      expect(counts[tester.renderObject(find.byType(PlayerBar))], isNull);
    });
  });

  testWidgets('the volume popup shows the volume in percent', (tester) async {
    await pumpApp(tester);
    await openSongs(tester);
    await player().setVolume(37);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(VolumeButton)));
    await tester.pumpAndSettle();

    expect(find.text('37%'), findsOneWidget);
  });

  testWidgets('the grown seek strip takes clicks along its whole height', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(480, 640));
    await openSongs(tester);
    backend.emitDuration.add(const Duration(seconds: 100));
    await tester.pump();

    final strip = tester.getRect(find.byType(SeekStrip));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: strip.center);
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();
    // The top row of the grown bar, above where the thin bar sits.
    await mouse.moveTo(Offset(strip.left + strip.width / 4, strip.top + 3));
    await tester.pumpAndSettle();
    await mouse.down(Offset(strip.left + strip.width / 4, strip.top + 3));
    await mouse.up();
    await tester.pumpAndSettle();

    expect(backend.calls.last, 'seek(${const Duration(seconds: 25)})');
  });

  testWidgets('spans the window below the collapsed sidebar', (tester) async {
    await pumpApp(tester);
    await openSongs(tester);
    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(PlayerBar)).left, 0);
    expect(tester.takeException(), isNull);
  });
}
