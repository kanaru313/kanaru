import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/player_bar.dart';
import 'package:kanaru/features/player/seek_strip.dart';
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

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

  testWidgets('shows the time label and repeat state', (tester) async {
    await pumpApp(tester);
    await openSongs(tester);
    backend.emitDuration.add(const Duration(minutes: 3, seconds: 5));
    backend.emitPosition.add(const Duration(seconds: 42));
    await tester.pump();

    expect(find.text('0:42 / 3:05'), findsOneWidget);

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

  testWidgets('the grown seek bar takes clicks along its whole height', (
    tester,
  ) async {
    await pumpApp(tester);
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
