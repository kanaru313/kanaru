import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/album_modal/album_modal_header.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/album_artwork.dart';
import 'package:kanaru/shared/widgets/library_grid/album_tile_data.dart';
import 'package:material_ui/material_ui.dart';

import 'album_modal_test_support.dart';

Future<void> _pump(
  WidgetTester tester, {
  AlbumTileData album = testAlbum,
  bool loaded = false,
  VoidCallback? onTap,
}) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AlbumModalHeader(
          album: album,
          summary: loaded ? linksOf().summary : null,
          onTap: onTap,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('64 px cover, artist, title, year only until loaded', (
    tester,
  ) async {
    await _pump(tester);
    expect(tester.getSize(find.byType(AlbumArtwork)), const Size(64, 64));
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Al'), findsOneWidget);
    expect(find.text('1999'), findsOneWidget);
  });

  testWidgets('counts and length show once loaded', (tester) async {
    await _pump(tester, loaded: true);
    expect(find.text('1999 • 3 songs • 10 min'), findsOneWidget);
  });

  testWidgets('Various artists and Unknown artist labels', (tester) async {
    await _pump(
      tester,
      album: const AlbumTileData(
        key: testAlbumKey,
        title: 'Al',
        variousArtists: true,
      ),
    );
    expect(find.text('Various artists'), findsOneWidget);
    await _pump(
      tester,
      album: const AlbumTileData(key: testAlbumKey, title: 'Al'),
    );
    expect(find.text('Unknown artist'), findsOneWidget);
  });

  testWidgets('Edit album art answers with a coming soon snackbar', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Edit album art'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining("isn't available yet"), findsOneWidget);
  });

  testWidgets('a tap on the cover or the text calls onTap', (tester) async {
    var taps = 0;
    await _pump(tester, onTap: () => taps++);
    await tester.tap(find.text('Al'));
    await tester.tap(find.byType(AlbumArtwork));
    expect(taps, 2);
  });

  testWidgets('the tappable header is a button with no keyboard focus', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, onTap: () {});
    final ink = tester.widget<InkWell>(
      find.ancestor(of: find.text('Al'), matching: find.byType(InkWell)),
    );
    expect(ink.canRequestFocus, isFalse);
    final data = tester
        .getSemantics(
          find.ancestor(of: find.text('Al'), matching: find.byType(InkWell)),
        )
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hint, 'Go to album');
    handle.dispose();
  });

  testWidgets('Edit album art keeps its own tap', (tester) async {
    var taps = 0;
    await _pump(tester, onTap: () => taps++);
    await tester.tap(find.byTooltip('Edit album art'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 0);
    expect(find.textContaining("isn't available yet"), findsOneWidget);
  });

  testWidgets('in the modal a tap on the header goes to the album', (
    tester,
  ) async {
    final host = await pumpAlbumHost(tester, links: linksOf());
    await openAlbumModalOf(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlbumModalHeader),
        matching: find.byType(AlbumArtwork),
      ),
    );
    await settleModal(tester);
    expect(find.byType(AlbumModalHeader), findsNothing);
    expect(host.location, albumLocation(testAlbumKey));
  });

  testWidgets('on the album page the header in the modal is not tappable', (
    tester,
  ) async {
    await pumpAlbumHost(tester, links: linksOf(), showAlbum: false);
    await openAlbumModalOf(tester);
    final header = find.byType(AlbumModalHeader);
    expect(header, findsOneWidget);
    // The Edit album art button has an InkWell of its own: look above the
    // title only.
    expect(
      find.ancestor(
        of: find.descendant(of: header, matching: find.text('Al')),
        matching: find.descendant(of: header, matching: find.byType(InkWell)),
      ),
      findsNothing,
    );
  });

  testWidgets('without onTap the header is not tappable', (tester) async {
    await _pump(tester);
    expect(
      find.ancestor(of: find.text('Al'), matching: find.byType(InkWell)),
      findsNothing,
    );
  });

  testWidgets('Edit album art is a button saying coming soon, with no focus', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    final data = tester
        .getSemantics(find.byTooltip('Edit album art'))
        .getSemanticsData();
    expect(data.hint, 'Coming soon');
    expect(data.flagsCollection.isButton, isTrue);
    expect(
      find.ancestor(
        of: find.byTooltip('Edit album art'),
        matching: find.byType(ExcludeFocus),
      ),
      findsWidgets,
    );
    handle.dispose();
  });
}
