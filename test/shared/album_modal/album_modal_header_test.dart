import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/album_modal/album_modal_header.dart';
import 'package:kanaru/shared/widgets/album_artwork.dart';
import 'package:kanaru/shared/widgets/library_grid/album_tile_data.dart';
import 'package:material_ui/material_ui.dart';

import 'album_modal_test_support.dart';

Future<void> _pump(
  WidgetTester tester, {
  AlbumTileData album = testAlbum,
  bool loaded = false,
}) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AlbumModalHeader(
          album: album,
          summary: loaded ? linksOf().summary : null,
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

  testWidgets('the header is not tappable', (tester) async {
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
