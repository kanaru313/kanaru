import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/artist_summaries.dart';
import 'package:kanaru/shared/widgets/artist_avatar.dart';
import 'package:kanaru/shared/widgets/artist_tile.dart';
import 'package:kanaru/shared/widgets/song_card.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const artist = ArtistSummary(
    key: 'joni',
    name: 'Joni',
    songCount: 3,
    albumCount: 1,
    durationMs: 600000,
  );

  Future<void> pump(
    WidgetTester tester, {
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
                body: ArtistTile(artist: artist, onTap: () {}, onPlay: () {}),
              ),
            );
          },
        ),
      ),
    ),
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('slot has the card extent at scale $scale', (tester) async {
      final scaler = TextScaler.linear(scale);
      late double expected;
      await pump(
        tester,
        scaler: scaler,
        onTheme: (theme) => expected = songCardExtent(theme, scaler),
      );
      expect(tester.getSize(find.byType(ArtistTile)).height, expected);
    });
  }

  testWidgets('draws a rounded card inset from the list edges', (tester) async {
    late ColorScheme colors;
    await pump(tester, onTheme: (theme) => colors = theme.colorScheme);
    final cardFinder = find
        .descendant(
          of: find.byType(ArtistTile),
          matching: find.byType(Material),
        )
        .first;
    final material = tester.widget<Material>(cardFinder);
    expect(material.color, songCardColor(colors));
    expect(material.shape, songCardShape);
    expect(songCardRadius, 12);

    final tile = tester.getRect(find.byType(ArtistTile));
    final card = tester.getRect(cardFinder);
    expect(card.left - tile.left, 16);
    expect(tile.right - card.right, 16);
    expect(card.top - tile.top, 4);
    expect(tile.bottom - card.bottom, 4);
    final avatar = tester.getRect(find.byType(ArtistAvatar));
    expect(avatar.size, const Size.square(64));
    expect(avatar.left - tile.left, 32);
  });

  testWidgets('shows the play button while hovered', (tester) async {
    await pump(tester);
    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(IconButton),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(opacity(), 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Joni')));
    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });
}
