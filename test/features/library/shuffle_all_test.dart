import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
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
