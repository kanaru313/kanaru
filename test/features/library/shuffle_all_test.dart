import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

void main() {
  LibraryHarness harness() => LibraryHarness(
    overrides: [
      playerServiceProvider.overrideWith(
        () => PlayerService(random: Random(3)),
      ),
    ],
  );

  Finder shuffleAll() => find.text('Shuffle all');

  testWidgets('queues every song shuffled in the list sort and plays', (
    tester,
  ) async {
    final h = harness();
    await openWithTracks(tester, h, const [
      TestTrack('c'),
      TestTrack('a'),
      TestTrack('d'),
      TestTrack('b'),
    ], location: '/songs');

    expect(shuffleAll(), findsOneWidget);
    await tester.tap(shuffleAll());
    await settleIo(tester, h);

    final state = h.container.read(playerServiceProvider);
    expect(
      [for (final t in state.queue.original) t.title],
      ['a', 'b', 'c', 'd'],
    );
    expect(state.queue.shuffled, isTrue);
    expect(state.queue.index, 0);
    expect(state.playing, isTrue);
    expect(h.backend.calls.where((c) => c.startsWith('open(')), hasLength(1));

    await h.container.read(playerServiceProvider.notifier).setShuffle(false);
    final unshuffled = h.container.read(playerServiceProvider).queue;
    expect(
      [for (final t in unshuffled.tracks) t.title],
      ['a', 'b', 'c', 'd'],
      reason: 'the Songs sort comes back',
    );
  });

  testWidgets('a second tap while the queue is being read does nothing', (
    tester,
  ) async {
    final h = harness();
    await openWithTracks(tester, h, const [
      TestTrack('a'),
      TestTrack('b'),
    ], location: '/songs');

    // Both presses reach the handler before the read can finish.
    final onPressed = tester
        .widget<TextButton>(
          find.ancestor(
            of: shuffleAll(),
            matching: find.bySubtype<TextButton>(),
          ),
        )
        .onPressed!;
    onPressed();
    onPressed();
    await settleIo(tester, h);

    expect(h.backend.calls.where((c) => c.startsWith('open(')), hasLength(1));
  });

  testWidgets('the queue moving on during the read does not drop it', (
    tester,
  ) async {
    final h = harness();
    await openWithTracks(tester, h, const [
      TestTrack('a'),
      TestTrack('b'),
    ], location: '/songs');
    final player = h.container.read(playerServiceProvider.notifier);
    await player.openTracks([
      Track.fromPath('/elsewhere/p.mp3'),
      Track.fromPath('/elsewhere/q.mp3'),
    ]);

    await tester.tap(shuffleAll());
    // The engine moves on and repeat changes before the read finishes: each
    // makes a new queue object, but nothing newer was opened.
    h.backend.advance();
    unawaited(player.cycleRepeat());
    unawaited(player.playNext([Track.fromPath('/elsewhere/r.mp3')]));
    await settleIo(tester, h);

    final state = h.container.read(playerServiceProvider);
    expect([for (final t in state.queue.original) t.title], ['a', 'b']);
    expect(state.queue.shuffled, isTrue);
    expect(h.backend.calls.where((c) => c.startsWith('open(')), hasLength(2));
  });

  testWidgets('a queue changed during the read is not replaced', (
    tester,
  ) async {
    final h = harness();
    await openWithTracks(tester, h, const [
      TestTrack('a'),
      TestTrack('b'),
    ], location: '/songs');

    await tester.tap(shuffleAll());
    // Another action lands before the read finishes.
    final other = Track.fromPath('/elsewhere/z.mp3');
    unawaited(
      h.container.read(playerServiceProvider.notifier).openTracks([other]),
    );
    await settleIo(tester, h);

    final state = h.container.read(playerServiceProvider);
    expect(state.queue.original, [other]);
    expect(state.queue.shuffled, isFalse);
    expect(h.backend.calls.where((c) => c.startsWith('open(')), hasLength(1));
    expect(find.byType(SnackBar), findsNothing, reason: 'dropped silently');
  });

  testWidgets('on a narrow header shows only the icon, with a tooltip', (
    tester,
  ) async {
    final h = harness();
    await insertTracks(tester, h, const [TestTrack('a'), TestTrack('b')]);
    await h.pump(tester, hasRoots: true);
    tester.view.physicalSize = const Size(500, 800);
    goTo(tester, h, '/songs');
    await tester.pumpAndSettle();

    expect(shuffleAll(), findsNothing);
    final button = find.byTooltip('Shuffle all');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await settleIo(tester, h);

    expect(h.container.read(playerServiceProvider).queue.shuffled, isTrue);
    expect(h.container.read(playerServiceProvider).playing, isTrue);
  });

  testWidgets('is disabled while the library has no songs', (tester) async {
    final h = harness();
    await tester.runAsync(() => h.db.addRoots(['/m'], now: 1));
    await h.pump(tester, hasRoots: true);
    goTo(tester, h, '/songs');
    await tester.pumpAndSettle();

    expect(shuffleAll(), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: shuffleAll(),
              matching: find.bySubtype<TextButton>(),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(h.container.read(playerServiceProvider).queue.original, isEmpty);
  });

  testWidgets('is not offered without a library root', (tester) async {
    final h = harness();
    await h.pump(tester);
    goTo(tester, h, '/songs');
    await tester.pumpAndSettle();

    expect(shuffleAll(), findsNothing);
  });
}
