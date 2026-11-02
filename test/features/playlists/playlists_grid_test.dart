import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/features/playlists/playlists_grid.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

PlaylistCard card(int id, String name, int count) => PlaylistCard(
  PlaylistSummary(id: id, name: name, createdAt: id, entryCount: count),
  const [],
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<PlaylistCard> cards, {
    double width = 1280,
    ValueChanged<PlaylistSummary>? onOpen,
  }) {
    tester.view
      ..physicalSize = Size(width, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlaylistsGrid(cards: cards, onOpen: onOpen ?? (_) {}),
          ),
        ),
      ),
    );
  }

  testWidgets('shows names and counts, and opens the tapped one', (
    tester,
  ) async {
    PlaylistSummary? opened;
    await pump(tester, [
      card(2, 'Gym', 3),
      card(1, 'Chill', 1),
    ], onOpen: (p) => opened = p);

    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('3 songs'), findsOneWidget);
    expect(find.text('Chill'), findsOneWidget);
    expect(find.text('1 song'), findsOneWidget);

    await tester.tap(find.text('Chill'));
    expect(opened?.id, 1);
  });

  // 24 px grid padding on each side, cards at most 200 px wide.
  for (final (width, columns) in [
    (360.0, 2),
    (600.0, 3),
    (840.0, 4),
    (1200.0, 6),
  ]) {
    testWidgets('lays out $columns columns at $width px', (tester) async {
      await pump(tester, [
        for (var i = 1; i <= 8; i++) card(i, 'List $i', i),
      ], width: width);

      final firstRowTop = tester.getTopLeft(find.byType(InkWell).first).dy;
      final firstRow = tester
          .widgetList<InkWell>(find.byType(InkWell))
          .map((w) => tester.getTopLeft(find.byWidget(w)))
          .where((p) => p.dy == firstRowTop);
      expect(firstRow.length, columns);
    });
  }

  for (final width in [480.0, 720.0, 1280.0]) {
    testWidgets('a two-line name at large text fits at $width px', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, [
        card(1, 'A long playlist name that needs more than one line', 12),
        card(2, 'Short', 0),
        card(3, 'Another quite long playlist name for the second row', 99),
      ], width: width);

      expect(tester.takeException(), isNull);
    });
  }
}
