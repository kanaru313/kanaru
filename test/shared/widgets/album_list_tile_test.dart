import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/album_artwork.dart';
import 'package:kanaru/shared/widgets/album_list_tile.dart';
import 'package:kanaru/shared/widgets/library_row.dart';
import 'package:kanaru/shared/widgets/song_card.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const album = AlbumSummary(
    key: AlbumKey('artist', 'title'),
    title: 'Blue',
    artist: 'Joni',
    trackCount: 3,
    durationMs: 600000,
    addedAt: 0,
  );

  Future<void> pump(
    WidgetTester tester, {
    required bool showTotals,
    TextScaler scaler = TextScaler.noScaling,
    void Function(ThemeData theme)? onTheme,
  }) => tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            onTheme?.call(Theme.of(context));
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: Scaffold(
                body: AlbumListTile(
                  album: album,
                  onTap: () {},
                  showTotals: showTotals,
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  testWidgets('shows the song count and length by default', (tester) async {
    await pump(tester, showTotals: true);

    expect(find.text('Blue'), findsOneWidget);
    expect(find.text('3 songs • 10 min'), findsOneWidget);
  });

  testWidgets('showTotals false hides the totals and keeps three lines of '
      'height', (tester) async {
    const scaler = TextScaler.linear(2);
    late double expected;

    Future<double> heightOf({required bool showTotals}) async {
      await pump(
        tester,
        showTotals: showTotals,
        scaler: scaler,
        onTheme: (theme) => expected = songCardExtent(theme, scaler),
      );
      return tester.getSize(find.byType(AlbumListTile)).height;
    }

    final withTotals = await heightOf(showTotals: true);
    final withoutTotals = await heightOf(showTotals: false);

    expect(find.text('Blue'), findsOneWidget);
    expect(find.text('Album'), findsOneWidget);
    expect(find.textContaining('songs'), findsNothing);
    expect(find.textContaining('min'), findsNothing);
    expect(withTotals, expected);
    expect(withoutTotals, expected);
    expect(expected, greaterThan(libraryRowMinHeight));
  });

  testWidgets('slot has the card extent at scale 1', (tester) async {
    late double expected;
    await pump(
      tester,
      showTotals: true,
      onTheme: (theme) =>
          expected = songCardExtent(theme, TextScaler.noScaling),
    );
    expect(tester.getSize(find.byType(AlbumListTile)).height, expected);
    expect(expected, greaterThanOrEqualTo(88));
  });

  testWidgets('draws a rounded card inset from the list edges', (tester) async {
    late ColorScheme colors;
    await pump(
      tester,
      showTotals: true,
      onTheme: (theme) => colors = theme.colorScheme,
    );
    final cardFinder = find
        .descendant(
          of: find.byType(AlbumListTile),
          matching: find.byType(Material),
        )
        .first;
    final material = tester.widget<Material>(cardFinder);
    expect(material.color, songCardColor(colors));
    expect(material.shape, songCardShape);
    expect(songCardRadius, 12);

    final tile = tester.getRect(find.byType(AlbumListTile));
    final card = tester.getRect(cardFinder);
    expect(card.left - tile.left, 16);
    expect(tile.right - card.right, 16);
    expect(card.top - tile.top, 4);
    expect(tile.bottom - card.bottom, 4);
    // Cover 64 px, 32 px from the list edge.
    final cover = tester.getRect(find.byType(AlbumArtwork));
    expect(cover.size, const Size.square(64));
    expect(cover.left - tile.left, 32);
  });

  testWidgets('shows the play button while hovered', (tester) async {
    await pump(tester, showTotals: true);
    final button = find.byType(IconButton);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(of: button, matching: find.byType(AnimatedOpacity)),
          )
          .opacity,
      0,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Blue')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(of: button, matching: find.byType(AnimatedOpacity)),
          )
          .opacity,
      1,
    );
  });
}
