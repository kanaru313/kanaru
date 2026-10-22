import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _tracks = [
  TestTrack('a', artist: 'Ann', album: 'Al', track: 1),
  TestTrack('b', artist: 'Ann', album: 'Al', track: 2),
  TestTrack('c', artist: 'Ann', album: 'Al', track: 3),
  TestTrack('other', artist: 'Bob', album: 'Other'),
];

void main() {
  LibraryHarness harness() => LibraryHarness(
    overrides: [
      playerServiceProvider.overrideWith(
        () => PlayerService(random: Random(3)),
      ),
    ],
  );

  void expectShuffledPage(LibraryHarness h, List<String> titles) {
    final queue = h.container.read(playerServiceProvider).queue;
    expect([for (final t in queue.original) t.title], titles);
    expect(queue.shuffled, isTrue);
  }

  testWidgets('Shuffle on an album page queues its tracks shuffled', (
    tester,
  ) async {
    final h = harness();
    await openWithTracks(
      tester,
      h,
      _tracks,
      location: albumLocation(const AlbumKey('ann', 'al')),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Shuffle'));
    await tester.pump();

    expectShuffledPage(h, ['a', 'b', 'c']);
    expect(h.container.read(playerServiceProvider).playing, isTrue);
  });

  testWidgets('Shuffle on an artist page queues their songs shuffled', (
    tester,
  ) async {
    final h = harness();
    await openWithTracks(tester, h, _tracks, location: artistLocation('ann'));

    await tester.tap(find.widgetWithText(FilledButton, 'Shuffle'));
    await tester.pump();

    expectShuffledPage(h, ['a', 'b', 'c']);
  });

  testWidgets('a narrow header shows Shuffle as an icon with a tooltip', (
    tester,
  ) async {
    final h = harness();
    await openWithTracks(
      tester,
      h,
      _tracks,
      location: albumLocation(const AlbumKey('ann', 'al')),
    );
    tester.view.physicalSize = const Size(500, 800);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Shuffle'), findsNothing);
    expect(find.byTooltip('Shuffle'), findsOneWidget);

    await tester.tap(find.byTooltip('Shuffle'));
    await tester.pump();
    expectShuffledPage(h, ['a', 'b', 'c']);
  });
}
