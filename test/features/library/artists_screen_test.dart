import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/shared/widgets/artist_tile.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';
import 'list_view_modes_override.dart';

const _tracks = [
  TestTrack('a1', artist: 'Ann', album: 'A'),
  TestTrack('a2', artist: 'Ann; Guest', album: 'A'),
  TestTrack('b1', artist: 'Bob', album: 'B', albumArtist: 'Various Artists'),
  TestTrack('b2', artist: 'Bob'),
  TestTrack('b3', artist: 'Bob'),
];

void main() {
  testWidgets('lists every credited artist with counts, sorted', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/artists');
    double top(String text) => tester.getTopLeft(find.text(text)).dy;

    expect(find.byType(ArtistTile), findsNWidgets(3));
    expect(find.text('Various Artists'), findsNothing);
    expect(find.text('1 album'), findsNWidgets(3));
    // Every test track lasts a second; a length above zero shows as 1 min.
    expect(find.text('2 songs • 1 min'), findsOneWidget);
    expect(find.text('3 songs • 1 min'), findsOneWidget);
    expect(find.text('1 song • 1 min'), findsOneWidget);
    expect(top('Ann'), lessThan(top('Bob')));
    expect(top('Bob'), lessThan(top('Guest')));

    await tester.tap(find.widgetWithText(TextButton, 'Name'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Songs'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Order: Ascending'));
    await tester.pumpAndSettle();

    expect(top('Bob'), lessThan(top('Ann')));
    expect(top('Ann'), lessThan(top('Guest')));
    expect(
      h.container.read(settingsProvider).artistSort,
      const SortChoice(ArtistSortField.songCount, descending: true),
    );
  });

  testWidgets('tapping an artist opens their page', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/artists');

    await tester.tap(find.text('Guest'));
    await tester.pumpAndSettle();

    expect(location(h), artistLocation('guest'));
    expect(find.text('Appears on'), findsOneWidget);
  });

  testWidgets('no artists yet', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('nobody'),
    ], location: '/artists');
    expect(find.text('No artists yet'), findsOneWidget);
  });
}
