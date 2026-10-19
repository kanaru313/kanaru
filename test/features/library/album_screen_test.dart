import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/albums/album_tracks_provider.dart';
import 'package:kanaru/features/library/library_route_keys.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

/// Two discs, stored out of order, plus a track by a guest.
const _album = [
  TestTrack('d2t1', artist: 'Ann', album: 'Two Discs', disc: 2, track: 1),
  TestTrack(
    'd1t2',
    artist: 'Ann; Guest',
    album: 'Two Discs',
    disc: 1,
    track: 2,
  ),
  TestTrack('d1t1', artist: 'Ann', album: 'Two Discs', disc: 1, track: 1),
  TestTrack('other', artist: 'Bob', album: 'Other'),
];

const _key = AlbumKey('ann', 'two discs');

void main() {
  List<String> queueTitles(LibraryHarness h) => [
    for (final t in h.container.read(playerServiceProvider).queue.original)
      t.title,
  ];

  testWidgets('a tile opens the album page, grouped by disc', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _album, location: '/albums');

    await tester.tap(find.text('Two Discs'));
    await tester.pumpAndSettle();

    expect(location(h), albumLocation(_key));
    expect(find.text('Disc 1'), findsOneWidget);
    expect(find.text('Disc 2'), findsOneWidget);
    expect(find.text('Ann; Guest'), findsOneWidget);
    expect(find.text('3 songs · 0:03'), findsOneWidget);
    final d1t1 = tester.getTopLeft(find.text('d1t1')).dy;
    final d1t2 = tester.getTopLeft(find.text('d1t2')).dy;
    final d2t1 = tester.getTopLeft(find.text('d2t1')).dy;
    expect(d1t1 < d1t2 && d1t2 < d2t1, isTrue);
    expect(find.text('other'), findsNothing);
  });

  testWidgets('tapping a track plays the album from it; Play starts it', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _album, location: albumLocation(_key));

    await tester.tap(find.text('d2t1'));
    await tester.pump();
    expect(queueTitles(h), ['d1t1', 'd1t2', 'd2t1']);
    expect(
      h.container.read(playerServiceProvider).queue.current?.title,
      'd2t1',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();
    expect(
      h.container.read(playerServiceProvider).queue.current?.title,
      'd1t1',
    );
    expect(h.backend.calls.last, startsWith('open(d1t1'));
  });

  testWidgets('one disc has no disc headings', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(
      tester,
      h,
      _album,
      location: albumLocation(const AlbumKey('bob', 'other')),
    );
    expect(find.text('other'), findsOneWidget);
    expect(find.textContaining('Disc'), findsNothing);
  });

  testWidgets('a broken or stale key shows not found', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _album, location: '/albums/garbage!');
    expect(find.text('Album not found'), findsOneWidget);

    goTo(tester, h, albumLocation(const AlbumKey('nobody', 'nothing')));
    await tester.pumpAndSettle();
    expect(find.text('Album not found'), findsOneWidget);
  });

  testWidgets('Back returns to the albums and the page query is disposed', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _album, location: '/albums');
    await tester.tap(find.text('Two Discs'));
    await tester.pumpAndSettle();
    expect(h.container.exists(albumTracksProvider(_key)), isTrue);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(location(h), '/albums');
    expect(find.text('Disc 1'), findsNothing);
    expect(h.container.exists(albumTracksProvider(_key)), isFalse);
  });
}
