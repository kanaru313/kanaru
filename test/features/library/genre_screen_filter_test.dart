import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/albums/album_grid_tile.dart';
import 'package:kanaru/shared/in_page_filter_registry.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _tracks = [
  TestTrack('Hello', genre: 'Rock', album: 'Mixed', albumArtist: 'X'),
  TestTrack('My Love', genre: 'Rock', artist: 'Zed'),
  TestTrack('Love Story', genre: 'Rock', album: 'Mixed', albumArtist: 'X'),
  TestTrack('Jazz love', genre: 'Jazz'),
];

final _rock = genreLocation('rock');

void main() {
  List<String> queued(LibraryHarness h) => [
    for (final t in h.container.read(playerServiceProvider).queue.original)
      t.title,
  ];

  Future<void> filterBy(WidgetTester tester, String text) async {
    if (find.byType(InPageSearchBox).evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Filter in this page'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.descendant(
        of: find.byType(InPageSearchBox),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.pump(const Duration(milliseconds: 150));
  }

  testWidgets('filters the songs of the genre and hides the albums', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);
    expect(find.byType(AlbumGridTile), findsOneWidget);

    await filterBy(tester, 'love');

    expect(find.byType(AlbumGridTile), findsNothing);
    expect(find.text('Hello'), findsNothing);
    expect(find.text('Jazz love'), findsNothing, reason: 'other genre');
    final story = tester.getTopLeft(find.text('Love Story')).dy;
    final love = tester.getTopLeft(find.text('My Love')).dy;
    expect(story < love, isTrue);
  });

  testWidgets('a match plays the filtered songs; Play plays them all', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);
    await filterBy(tester, 'love');

    await tester.tap(find.text('Love Story'));
    await tester.pump();
    expect(queued(h), ['Love Story', 'My Love']);

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();
    expect(queued(h), hasLength(3));
  });

  testWidgets('no match says so; Esc brings the albums back', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);

    await filterBy(tester, 'zzz');
    expect(find.text('No songs match “zzz”'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlbumGridTile), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('Ctrl+F still works once the button scrolled out of view', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, [
      for (var i = 0; i < 60; i++) TestTrack('Song $i', genre: 'Rock'),
    ], location: _rock);
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Filter in this page'), findsNothing);

    expect(InPageFilterRegistry.instance.openTop(), isTrue);
    await tester.pumpAndSettle();

    expect(find.byType(InPageSearchBox), findsOneWidget);
    expect(find.byType(InPageSearchBox).hitTestable(), findsOneWidget);
  });
}
