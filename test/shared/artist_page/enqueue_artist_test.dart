import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/shared/artist_page/enqueue_artist.dart';

import '../../features/library/browse_test_data.dart';
import '../../features/library/library_test_harness.dart';

const _tracks = [
  TestTrack('a1', artist: 'Ann', album: 'Alpha', track: 1),
  TestTrack('a2', artist: 'Ann', album: 'Alpha', track: 2),
  TestTrack('b1', artist: 'Bob', album: 'Beta', track: 1),
];

void main() {
  List<String> queue(LibraryHarness h) => [
    for (final t in h.container.read(playerServiceProvider).queue.tracks)
      t.title,
  ];

  testWidgets('playArtistIn plays the artist songs in page order', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/artists');

    await playArtistIn(h.container, 'ann');
    await tester.pump();

    expect(queue(h), ['a1', 'a2']);
    expect(h.container.read(playerServiceProvider).queue.shuffled, isFalse);
  });

  testWidgets('playArtistIn with shuffle shuffles the artist songs', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/artists');

    await playArtistIn(h.container, 'ann', shuffle: true);
    await tester.pump();

    expect(queue(h).toSet(), {'a1', 'a2'});
    expect(h.container.read(playerServiceProvider).queue.shuffled, isTrue);
  });

  testWidgets('playArtistIn leaves the queue alone for an unknown artist', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/artists');

    await playArtistIn(h.container, 'nobody');
    await tester.pump();

    expect(queue(h), isEmpty);
  });
}
