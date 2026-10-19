import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/sidebar/sidebar_item.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/artists/artist_tracks_provider.dart';
import 'package:kanaru/features/library/library_route_keys.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _tracks = [
  TestTrack(
    'own',
    artist: 'Ann',
    album: 'Mine',
    albumArtist: 'Ann',
    year: 2001,
  ),
  TestTrack('guest', artist: 'X; Ann', album: 'Theirs', albumArtist: 'X'),
  TestTrack('loose', artist: 'Ann'),
  TestTrack('anna', artist: 'Anna'),
];

final _ann = artistLocation('ann');

void main() {
  testWidgets('shows albums, songs and appearances', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _ann);

    Finder onPage(String text) => find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.text(text),
    );
    expect(find.text('2 albums · 3 songs'), findsOneWidget);
    expect(onPage('Albums'), findsOneWidget);
    expect(find.text('Mine'), findsOneWidget);
    expect(onPage('Songs'), findsOneWidget);
    expect(find.text('Appears on'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Theirs'),
      200,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Theirs'), findsOneWidget);
    expect(find.text('anna'), findsNothing, reason: 'Anna is someone else');
  });

  testWidgets('a song plays the Songs section from it; Play from the top', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _ann);

    await tester.tap(find.text('guest').last);
    await tester.pump();
    final queue = h.container.read(playerServiceProvider).queue;
    expect(
      [for (final t in queue.original) t.title],
      ['own', 'guest', 'loose'],
    );
    expect(queue.current?.title, 'guest');

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();
    expect(h.container.read(playerServiceProvider).queue.current?.title, 'own');
  });

  testWidgets('an album opens inside the Artists branch', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _ann);

    await tester.tap(find.text('Mine'));
    await tester.pumpAndSettle();

    expect(
      location(h),
      artistAlbumLocation('ann', const AlbumKey('ann', 'mine')),
    );
    expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
    expect(_selectedSidebarItem(tester), 'Artists');
  });

  testWidgets('the artist on an album page links to the Artists branch', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(
      tester,
      h,
      _tracks,
      location: albumLocation(const AlbumKey('ann', 'mine')),
    );
    expect(_selectedSidebarItem(tester), 'Albums');

    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();

    expect(location(h), _ann);
    expect(_selectedSidebarItem(tester), 'Artists');
  });

  testWidgets('an album artist without own tracks is plain text', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('t', artist: 'Ann', album: 'Mix', albumArtist: 'Various'),
    ], location: albumLocation(const AlbumKey('various', 'mix')));
    await tester.tap(find.text('Various'));
    await tester.pumpAndSettle();
    expect(location(h), albumLocation(const AlbumKey('various', 'mix')));
  });

  testWidgets('a broken key or unknown artist shows not found', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/artists/%21%21');
    expect(find.text('Artist not found'), findsOneWidget);

    goTo(tester, h, artistLocation('nobody'));
    await tester.pumpAndSettle();
    expect(find.text('Artist not found'), findsOneWidget);
  });

  testWidgets('leaving the page disposes its query', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _ann);
    expect(h.container.exists(artistTracksProvider('ann')), isTrue);

    goTo(tester, h, '/artists');
    await tester.pumpAndSettle();
    expect(h.container.exists(artistTracksProvider('ann')), isFalse);
    // Lets drift's zero-delay stream cleanup timer run.
    await tester.pump(const Duration(milliseconds: 1));
  });
}

/// The label of the sidebar item drawn as selected.
String? _selectedSidebarItem(WidgetTester tester) {
  for (final item in tester.widgetList<SidebarItem>(find.byType(SidebarItem))) {
    if (item.selected) return item.label;
  }
  return null;
}
