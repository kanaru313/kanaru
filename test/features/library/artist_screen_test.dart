import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/sidebar/sidebar_item.dart';
import 'package:kanaru/core/database/library_database.dart' show AlbumKey;
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/library/artists/artist_page_data.dart';
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

    // Something else is queued, then Play queues the whole section again.
    await h.container.read(playerServiceProvider.notifier).openTracks([
      Track.fromPath('/other.mp3'),
    ]);
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();
    final played = h.container.read(playerServiceProvider).queue;
    expect(
      [for (final t in played.original) t.title],
      ['own', 'guest', 'loose'],
    );
    expect(played.current?.title, 'own');
  });

  testWidgets('empty sections are hidden', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: artistLocation('x'));
    Finder onPage(String text) => find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.text(text),
    );
    // X owns "Theirs" and appears nowhere else.
    expect(onPage('Albums'), findsOneWidget);
    expect(onPage('Appears on'), findsNothing);

    goTo(tester, h, artistLocation('anna'));
    await tester.pumpAndSettle();
    // Anna has a song without album: neither album section.
    expect(onPage('Albums'), findsNothing);
    expect(onPage('Appears on'), findsNothing);
    expect(onPage('Songs'), findsOneWidget);
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
    expect(h.container.exists(artistPageProvider('ann')), isTrue);

    goTo(tester, h, '/artists');
    await tester.pumpAndSettle();
    expect(h.container.exists(artistPageProvider('ann')), isFalse);
    // Lets drift's zero-delay stream cleanup timer run.
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('real tags: a joined artist has their own page and songs', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack(
        'Khi Cô Đơn Em Nhớ Đến Ai',
        artist: 'Ban nhạc Hương Mùa Hè;SUNI Hạ Linh',
      ),
      TestTrack(
        'one',
        artist: 'Chau Khai Phong',
        album: 'Châu Khải Phong Best Collection',
      ),
      TestTrack(
        'two',
        artist: 'Chau Khai Phong feat. Trịnh Đình Quang',
        album: 'Châu Khải Phong Best Collection',
      ),
    ], location: '/artists');

    expect(find.text('Ban nhạc Hương Mùa Hè'), findsOneWidget);
    expect(find.text('Trịnh Đình Quang'), findsOneWidget);
    await tester.tap(find.text('SUNI Hạ Linh'));
    await tester.pumpAndSettle();
    expect(location(h), artistLocation('suni hạ linh'));
    expect(find.text('Khi Cô Đơn Em Nhớ Đến Ai'), findsOneWidget);

    goTo(tester, h, artistLocation('chau khai phong'));
    await tester.pumpAndSettle();
    expect(find.text('1 album · 2 songs'), findsOneWidget);
    expect(find.text('Châu Khải Phong Best Collection'), findsOneWidget);
  });
}

/// The label of the sidebar item drawn as selected.
String? _selectedSidebarItem(WidgetTester tester) {
  for (final item in tester.widgetList<SidebarItem>(find.byType(SidebarItem))) {
    if (item.selected) return item.label;
  }
  return null;
}
