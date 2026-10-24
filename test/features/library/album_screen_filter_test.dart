import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/shared/in_page_filter_registry.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _album = [
  TestTrack(
    'Hello',
    artist: 'Lovers',
    album: 'Two Discs',
    albumArtist: 'Ann',
    disc: 2,
    track: 1,
  ),
  TestTrack(
    'Love Story',
    artist: 'Ann',
    album: 'Two Discs',
    albumArtist: 'Ann',
    disc: 1,
    track: 1,
  ),
  TestTrack(
    'Other',
    artist: 'Ann',
    album: 'Two Discs',
    albumArtist: 'Ann',
    disc: 2,
    track: 2,
  ),
  TestTrack(
    'My Love',
    artist: 'Ann',
    album: 'Two Discs',
    albumArtist: 'Ann',
    disc: 1,
    track: 2,
  ),
  TestTrack('Else', artist: 'Bob', album: 'Elsewhere'),
];

final _location = albumLocation(const AlbumKey('ann', 'two discs'));

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

  testWidgets('filtering lists the matches flat, best first, without discs', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _album, location: _location);
    expect(find.text('Disc 1'), findsOneWidget);

    await filterBy(tester, 'love');

    expect(find.text('Disc 1'), findsNothing);
    expect(find.text('Disc 2'), findsNothing);
    expect(find.text('Other'), findsNothing);
    final y = [
      for (final t in ['Love Story', 'My Love', 'Hello'])
        tester.getTopLeft(find.text(t)).dy,
    ];
    expect(y[0] < y[1] && y[1] < y[2], isTrue, reason: '$y');
  });

  testWidgets('tapping a match plays the filtered list from it', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _album, location: _location);
    await filterBy(tester, 'love');

    await tester.tap(find.text('My Love'));
    await tester.pump();

    expect(queued(h), ['Love Story', 'My Love', 'Hello']);
    expect(
      h.container.read(playerServiceProvider).queue.current?.title,
      'My Love',
    );
  });

  testWidgets('Play still plays the whole album', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _album, location: _location);
    await filterBy(tester, 'love');

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();

    expect(queued(h), ['Love Story', 'My Love', 'Hello', 'Other']);
  });

  testWidgets('no match says so; clearing brings the discs back', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _album, location: _location);

    await filterBy(tester, 'zzz');
    expect(find.text('No songs match “zzz”'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear filter'));
    await tester.pumpAndSettle();
    expect(find.text('No songs match “zzz”'), findsNothing);
    expect(find.text('Disc 1'), findsOneWidget);
  });

  testWidgets('Esc closes the filter and shows every track again', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _album, location: _location);
    await filterBy(tester, 'love');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(InPageSearchBox), findsNothing);
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Disc 2'), findsOneWidget);
  });

  testWidgets('Ctrl+F reaches the filter of the page; leaving drops it', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _album, location: _location);

    expect(InPageFilterRegistry.instance.openTop(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(InPageSearchBox), findsOneWidget);

    goTo(tester, h, '/albums');
    await tester.pumpAndSettle();
    expect(InPageFilterRegistry.instance.openTop(), isFalse);
    goTo(tester, h, _location);
    await tester.pumpAndSettle();
    expect(find.byType(InPageSearchBox), findsNothing);
  });

  testWidgets('Ctrl+F still works once the button scrolled out of view', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, [
      for (var i = 0; i < 60; i++)
        TestTrack(
          'Song $i',
          artist: 'Ann',
          album: 'Two Discs',
          albumArtist: 'Ann',
          track: i,
        ),
    ], location: _location);
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
