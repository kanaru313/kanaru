import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/features/library/albums/album_page_data.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _key = AlbumKey('', 'mix');

AlbumPageData _page({required bool various}) => AlbumPageData(
  key: _key,
  album: AlbumSummary(
    key: _key,
    title: 'Mix',
    artist: 'Ann',
    trackCount: 2,
    addedAt: 1,
    variousArtists: various,
  ),
  tracks: const [
    BrowseTrack(id: 1, path: '/m/1.flac', title: 'One', artist: 'Ann'),
    BrowseTrack(id: 2, path: '/m/2.flac', title: 'Two', artist: 'Bob'),
  ],
);

void main() {
  testWidgets('a merged album shows each track\'s own artist', (tester) async {
    final h = LibraryHarness(
      overrides: [
        albumPageProvider.overrideWith(
          (ref, key) => Stream.value(_page(various: true)),
        ),
      ],
    );
    await openWithTracks(tester, h, const [], location: albumLocation(_key));

    expect(find.text('Various artists'), findsOneWidget);
    // Ann is the shown album artist of the merged album, yet her row names her.
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('a filtered merged album still shows the row\'s own artist', (
    tester,
  ) async {
    final h = LibraryHarness(
      overrides: [
        albumPageProvider.overrideWith(
          (ref, key) => Stream.value(_page(various: true)),
        ),
      ],
    );
    await openWithTracks(tester, h, const [], location: albumLocation(_key));

    await tester.tap(find.byTooltip('Filter in this page'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(InPageSearchBox),
        matching: find.byType(TextField),
      ),
      'Two',
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(find.text('Two'), findsWidgets);
    expect(find.text('One'), findsNothing);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('a single-artist album does not repeat the album artist', (
    tester,
  ) async {
    final h = LibraryHarness(
      overrides: [
        albumPageProvider.overrideWith(
          (ref, key) => Stream.value(_page(various: false)),
        ),
      ],
    );
    await openWithTracks(tester, h, const [], location: albumLocation(_key));

    // "Ann" once in the header; her row stays quiet.
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });
}
