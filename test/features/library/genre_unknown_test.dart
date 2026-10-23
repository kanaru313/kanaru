import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/genres/genre_grid_tile.dart';
import 'package:kanaru/features/library/genres/genre_tile.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _tracks = [
  TestTrack('rock one', genre: 'Rock', album: 'Loud', albumArtist: 'X'),
  TestTrack('plain', album: 'Quiet', albumArtist: 'X'),
  TestTrack('blank', genre: '  ; '),
  TestTrack('mixed', album: 'Loud', albumArtist: 'X'),
];

final _unknown = genreLocation(unknownGenreKey);

void main() {
  List<String> queued(LibraryHarness h) => [
    for (final t in h.container.read(playerServiceProvider).queue.original)
      t.title,
  ];

  testWidgets('the list ends with Unknown genre and its song count', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/genres');

    final tiles = tester.widgetList<GenreTile>(find.byType(GenreTile)).toList();
    expect([for (final t in tiles) t.genre.key], ['rock', unknownGenreKey]);
    expect(find.text('Unknown genre'), findsOneWidget);
    expect(find.text('3 songs'), findsOneWidget);
    expect(find.text('1 song'), findsOneWidget);
  });

  testWidgets('the grid shows it too', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/genres');

    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();

    expect(find.byType(GenreGridTile), findsNWidgets(2));
    expect(find.text('Unknown genre'), findsOneWidget);
  });

  testWidgets('the entry opens a page with its albums and songs', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/genres');

    await tester.tap(find.text('Unknown genre'));
    await tester.pumpAndSettle();

    expect(location(h), _unknown);
    expect(find.text('Unknown genre'), findsOneWidget, reason: 'header name');
    expect(find.text('2 albums · 3 songs'), findsOneWidget);
    for (final title in ['plain', 'blank', 'mixed']) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.text('rock one'), findsNothing);
  });

  testWidgets('Play queues the songs of the unknown genre', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _unknown);

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();

    expect(queued(h), ['blank', 'mixed', 'plain']);
  });

  testWidgets('with only untagged songs the list is just that entry', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('x'),
    ], location: '/genres');

    expect(find.byType(GenreTile), findsOneWidget);
    expect(find.text('Unknown genre'), findsOneWidget);
    expect(find.text('No genres yet'), findsNothing);
  });

  testWidgets('a library of tagged songs only has no such entry', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('x', genre: 'Rock'),
    ], location: '/genres');

    expect(find.text('Unknown genre'), findsNothing);
  });

  testWidgets('the page says not found when no song is left', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('x', genre: 'Rock'),
    ], location: _unknown);

    expect(find.text('Genre not found'), findsOneWidget);
  });
}
