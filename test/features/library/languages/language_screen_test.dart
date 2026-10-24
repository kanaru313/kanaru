import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/albums/album_grid_tile.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:material_ui/material_ui.dart';

import '../browse_test_data.dart';
import '../library_test_harness.dart';
import 'language_test_data.dart';

const _tracks = [
  LangTrack('b', 'eng', album: 'Mixed', albumArtist: 'X'),
  LangTrack('a', 'en-GB'),
  LangTrack('c', 'eng; vie'),
  LangTrack('v', 'vie', album: 'Mixed', albumArtist: 'X'),
  LangTrack('n', null),
];

void main() {
  List<String> queued(LibraryHarness h) => [
    for (final t in h.container.read(playerServiceProvider).queue.original)
      t.title,
  ];

  testWidgets('shows the albums and songs of the language', (tester) async {
    final h = LibraryHarness();
    await openWithLanguages(
      tester,
      h,
      _tracks,
      location: languageLocation('eng'),
    );

    expect(find.text('English'), findsOneWidget, reason: 'header name');
    expect(find.text('1 album · 3 songs'), findsOneWidget);
    expect(find.byType(AlbumGridTile), findsOneWidget);
    for (final title in ['a', 'b', 'c']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('v'), findsNothing, reason: 'a Vietnamese-only song');
    expect(find.text('n'), findsNothing, reason: 'an untagged song');
  });

  testWidgets('Play queues the songs of the language by title', (tester) async {
    final h = LibraryHarness();
    await openWithLanguages(
      tester,
      h,
      _tracks,
      location: languageLocation('eng'),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();

    expect(queued(h), ['a', 'b', 'c']);
    expect(h.container.read(playerServiceProvider).queue.current?.title, 'a');
  });

  testWidgets('a song plays the songs from it', (tester) async {
    final h = LibraryHarness();
    await openWithLanguages(
      tester,
      h,
      _tracks,
      location: languageLocation('eng'),
    );

    await tester.tap(find.text('b'));
    await tester.pump();

    expect(queued(h), ['a', 'b', 'c']);
    expect(h.container.read(playerServiceProvider).queue.current?.title, 'b');
  });

  testWidgets('a language page lists its own songs only', (tester) async {
    final h = LibraryHarness();
    await openWithLanguages(
      tester,
      h,
      _tracks,
      location: languageLocation('vie'),
    );

    expect(find.text('Vietnamese'), findsOneWidget, reason: 'header name');
    expect(find.text('c'), findsOneWidget, reason: 'tagged eng; vie');
    expect(find.text('v'), findsOneWidget);
    expect(find.text('a'), findsNothing, reason: 'an eng-only song');
    expect(find.text('b'), findsNothing, reason: 'an eng-only song');
  });

  testWidgets('a broken key or unknown language shows not found', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithLanguages(tester, h, _tracks, location: '/languages/%21%21');
    expect(find.text('Language not found'), findsOneWidget);

    goTo(tester, h, languageLocation('nobody'));
    await tester.pumpAndSettle();
    expect(find.text('Language not found'), findsOneWidget);
  });
}
